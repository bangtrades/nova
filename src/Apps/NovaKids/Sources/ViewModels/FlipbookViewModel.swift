import Foundation
import NovaCore
import NovaVoice

/// ViewModel for the flipbook card viewer.
///
/// Manages card navigation, progress tracking, voice narration, and state for the
/// full-screen card viewing experience.
@MainActor
public class FlipbookViewModel: ObservableObject {
    @Published var lesson: Lesson
    @Published var cards: [Card] = []
    @Published var currentCardIndex: Int = 0
    @Published var completedCardIndices: Set<Int> = []
    // S11-19: `isLoading` now has a real fetch path — when the injected
    // lesson arrives without embedded cards (the Tier-1 `fetchLessons`
    // list endpoint returns summaries, not full card arrays), the view
    // model lazily fetches `/api/v1/lessons/:id/cards` via `loadCardsIfNeeded()`.
    @Published var isLoading: Bool = false
    @Published var loadError: APIError?
    @Published var showDashyHint: Bool = false
    @Published var autoNarrate: Bool {
        didSet {
            UserDefaults.standard.set(autoNarrate, forKey: "flipbook.autoNarrate")
        }
    }

    /// Voice manager for TTS capabilities.
    public let voiceManager: VoiceManager

    /// Injected post-construction via `attach(apiRouter:)`. The init is kept
    /// zero-router so `StateObject(wrappedValue: FlipbookViewModel(lesson:…))`
    /// callsites + previews stay intact. When nil, `loadCardsIfNeeded()`
    /// falls back to mock cards so previews still render a full flipbook.
    private var apiRouter: APIRouter?

    public init(lesson: Lesson, voiceManager: VoiceManager) {
        self.lesson = lesson
        self.voiceManager = voiceManager

        // Load auto-narrate preference
        self.autoNarrate = UserDefaults.standard.bool(forKey: "flipbook.autoNarrate")

        // Load cards from lesson synchronously if the caller already has
        // them. When `lesson.cards` is nil we defer to `loadCardsIfNeeded()`
        // so the View can await the fetch and surface `isLoading`.
        if let lessonCards = lesson.cards, !lessonCards.isEmpty {
            self.cards = lessonCards.sorted { $0.sortOrder < $1.sortOrder }

            // Auto-narrate the first card if enabled and we have content now.
            if autoNarrate {
                Task {
                    try? await speakCurrentCard()
                }
            }
        }
        // If cards are nil/empty we do NOT pre-populate with mock data here
        // — `loadCardsIfNeeded()` handles the router-vs-preview decision.
    }

    /// Wire the API router in post-construction. Idempotent — re-calling
    /// (e.g. a `.task` re-trigger on tab switch) is a no-op after the first.
    public func attach(apiRouter: APIRouter) {
        guard self.apiRouter == nil else { return }
        self.apiRouter = apiRouter
    }

    /// Fetches cards if the lesson arrived without them. Called from the
    /// View's `.task` after `attach(apiRouter:)`. Safe to call multiple times
    /// — once cards are non-empty, subsequent calls short-circuit.
    ///
    /// Live path: `GET /api/v1/lessons/:id/cards` via `apiRouter.fetchCards`.
    /// Preview / nil-router path: falls through to `generateMockCards()` so
    /// `#Preview { FlipbookView(lesson:) }` renders a full flipbook without
    /// needing a backend.
    public func loadCardsIfNeeded() async {
        guard cards.isEmpty else { return }

        guard let apiRouter else {
            // Preview / unit-test path — the mock generator produces a 5-card
            // deck so the Flipbook can exercise swipe + progress dots.
            self.cards = generateMockCards()
            if autoNarrate {
                try? await speakCurrentCard()
            }
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let fetched = try await apiRouter.fetchCards(lessonId: lesson.id)
            self.cards = fetched.sorted { $0.sortOrder < $1.sortOrder }
            self.loadError = nil
            if autoNarrate && !cards.isEmpty {
                try? await speakCurrentCard()
            }
        } catch let error as APIError {
            self.loadError = error
        } catch {
            self.loadError = .custom(error.localizedDescription)
        }
    }

    /// Retry handler for the error banner's "Try Again" button. Clears the
    /// error and re-runs the fetch.
    public func retryLoad() async {
        loadError = nil
        await loadCardsIfNeeded()
    }

    /// Generates mock cards for demonstration.
    private func generateMockCards() -> [Card] {
        var mockCards: [Card] = []

        for i in 0..<5 {
            let cardType: Card.CardType = i % 2 == 0 ? .story : .concept

            let card = Card(
                id: UUID(),
                lessonId: lesson.id,
                type: cardType,
                sortOrder: i,
                content: Card.CardContent(
                    title: "Card \(i + 1)",
                    narrativeText: cardType == .story
                        ? "Discover the wonders of AI and technology!" : nil,
                    explanation: cardType == .concept
                        ? "Learning happens through observation and pattern recognition." : nil
                ),
                voiceScript: cardType == .story
                    ? "Discover the wonders of AI and technology!"
                    : "Learning happens through observation and pattern recognition."
            )
            mockCards.append(card)
        }

        return mockCards
    }

    /// Moves to the next card.
    func nextCard() {
        if currentCardIndex < cards.count - 1 {
            markCurrentCardComplete()
            currentCardIndex += 1

            // Auto-narrate if enabled
            if autoNarrate {
                Task {
                    try? await speakCurrentCard()
                }
            }
        }
    }

    /// Moves to the previous card.
    func previousCard() {
        if currentCardIndex > 0 {
            currentCardIndex -= 1
        }
    }

    /// Navigates to a specific card by index.
    func goToCard(_ index: Int) {
        guard index >= 0 && index < cards.count else { return }
        currentCardIndex = index
    }

    /// Marks the current card as complete.
    func markCurrentCardComplete() {
        completedCardIndices.insert(currentCardIndex)
    }

    /// Gets the current card.
    var currentCard: Card? {
        guard currentCardIndex >= 0 && currentCardIndex < cards.count else { return nil }
        return cards[currentCardIndex]
    }

    /// Gets overall progress percentage.
    var progressPercentage: Double {
        guard !cards.isEmpty else { return 0 }
        return Double(completedCardIndices.count) / Double(cards.count)
    }

    /// Checks if lesson is complete.
    var isLessonComplete: Bool {
        completedCardIndices.count == cards.count
    }

    /// Checks if user is on the last card.
    var isLastCard: Bool {
        currentCardIndex == cards.count - 1
    }

    /// Gets the current hint for the active card.
    var currentHint: String {
        guard let card = currentCard else {
            return "Keep going! You're doing great!"
        }

        // Generate hint based on card type and content
        switch card.type {
        case .story:
            return generateStoryHint(card: card)
        case .concept:
            return generateConceptHint(card: card)
        default:
            return "Try exploring this card to learn something new!"
        }
    }

    // MARK: - Voice Narration

    /// Speaks the current card's voice script.
    ///
    /// Prefers the voiceScript if available, otherwise falls back to
    /// narrativeText (story) or explanation (concept).
    public func speakCurrentCard() async throws {
        guard let card = currentCard else { return }

        let textToSpeak = card.voiceScript
            ?? card.content.narrativeText
            ?? card.content.explanation
            ?? ""

        guard !textToSpeak.isEmpty else { return }

        // S13-09: VoiceManager now defaults to OpenAI TTS through the
        // backend proxy. The kid's selected persona lives on
        // voiceManager.currentVoice and was set at picker / app-launch
        // time from VoicePreferenceStore. AVSpeech survives only as the
        // offline fallback.
        try await voiceManager.speak(text: textToSpeak)
    }

    /// Stops the current speech.
    public func stopSpeaking() {
        voiceManager.stop()
    }

    // MARK: - Private Hint Generators

    private func generateStoryHint(card: Card) -> String {
        let hints = [
            "Listen carefully to the story. There might be something important!",
            "Think about what Dashy is trying to teach you in this story.",
            "Pay attention to the colors and shapes — they're clues!",
            "This story is showing you how AI works in real life."
        ]
        return hints[currentCardIndex % hints.count]
    }

    private func generateConceptHint(card: Card) -> String {
        let hints = [
            "Try to remember what you learned on the previous card.",
            "This concept might remind you of something in the real world!",
            "Can you think of an example of this happening?",
            "Look at the different parts of this concept carefully."
        ]
        return hints[currentCardIndex % hints.count]
    }
}
