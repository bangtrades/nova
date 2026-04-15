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
    @Published var isLoading: Bool = false
    @Published var showSparkyHint: Bool = false
    @Published var autoNarrate: Bool {
        didSet {
            UserDefaults.standard.set(autoNarrate, forKey: "flipbook.autoNarrate")
        }
    }

    /// Voice manager for TTS capabilities.
    public let voiceManager: VoiceManager

    public init(lesson: Lesson, voiceManager: VoiceManager) {
        self.lesson = lesson
        self.voiceManager = voiceManager

        // Load auto-narrate preference
        self.autoNarrate = UserDefaults.standard.bool(forKey: "flipbook.autoNarrate")

        // Load cards from lesson
        if let lessonCards = lesson.cards {
            self.cards = lessonCards.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            // Generate mock cards if not available
            self.cards = generateMockCards()
        }

        // Auto-narrate the first card if enabled
        if autoNarrate && !cards.isEmpty {
            Task {
                try? await speakCurrentCard()
            }
        }
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

        try await voiceManager.speak(text: textToSpeak, preferRemote: false)
    }

    /// Stops the current speech.
    public func stopSpeaking() {
        voiceManager.stop()
    }

    // MARK: - Private Hint Generators

    private func generateStoryHint(card: Card) -> String {
        let hints = [
            "Listen carefully to the story. There might be something important!",
            "Think about what Sparky is trying to teach you in this story.",
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
