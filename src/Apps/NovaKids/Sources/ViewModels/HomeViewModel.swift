import Foundation
import NovaCore

/// ViewModel for the Home screen.
///
/// Manages the display of featured lessons, current progress, and learning paths.
///
/// S11-19: zero-arg `init()` preserved — callsite is `@StateObject private var
/// viewModel = HomeViewModel()` in both `HomeView` and `EnhancedHomeView`, and
/// changing that constructor would ripple through every preview. Instead, the
/// View attaches `apiRouter` + `appState` in its `.task`. `refresh()` falls
/// through to the mock path when the router is nil so previews stay green.
@MainActor
public class HomeViewModel: ObservableObject {
    @Published var childName: String = "Explorer"
    @Published var currentLesson: Lesson?
    @Published var learningPaths: [LearningPath] = []
    @Published var allLessons: [Lesson] = []
    @Published var isLoading: Bool = false
    @Published var loadError: APIError?

    /// Injected after construction; idempotent attach.
    private var apiRouter: APIRouter?
    /// Child id sourced from `KidsAppState.currentChild` via the View. Needed
    /// for `fetchProgress(childId:)`. Optional because the auth flow may not
    /// have selected a child yet; when nil we skip the progress call but
    /// still fetch lessons + paths.
    private var childId: UUID?

    /// Initialize with mock data.
    public init() {
        loadMockData()
    }

    /// Wire the router + current child in from the View's `.task`. Re-callable
    /// so a child switch (S12) can re-point the VM without recreating it.
    public func attach(apiRouter: APIRouter, childId: UUID?) {
        self.apiRouter = apiRouter
        self.childId = childId
    }

    /// Loads mock data for preview and development.
    private func loadMockData() {
        let userId = UUID()

        // Create 3 learning paths
        learningPaths = [
            LearningPath(
                id: UUID(),
                userId: userId,
                title: "What is AI?",
                description: "Learn the basics of artificial intelligence",
                color: "blue",
                icon: "brain.head.profile",
                sortOrder: 1,
                stage: .explorer,
                isPremium: false
            ),
            LearningPath(
                id: UUID(),
                userId: userId,
                title: "How Computers Think",
                description: "Understand how computers make decisions",
                color: "orange",
                icon: "cpu",
                sortOrder: 2,
                stage: .explorer,
                isPremium: false
            ),
            LearningPath(
                id: UUID(),
                userId: userId,
                title: "Talk to Robots",
                description: "Communicate with AI assistants",
                color: "purple",
                icon: "bubble.left.and.bubble.right.fill",
                sortOrder: 3,
                stage: .thinker,
                isPremium: true
            ),
        ]

        // Create 6 sample lessons with varied difficulty
        allLessons = [
            Lesson(
                id: UUID(),
                pathId: learningPaths[0].id,
                userId: userId,
                title: "What Makes AI Smart?",
                description: "Learn how AI learns from data",
                thumbnailURL: nil,
                difficulty: 1,
                sourceURL: nil,
                aiAnalysis: nil,
                status: .published,
                sortOrder: 1,
                createdAt: Date(),
                publishedAt: Date(),
                cards: mockCardsForLesson(count: 5)
            ),
            Lesson(
                id: UUID(),
                pathId: learningPaths[0].id,
                userId: userId,
                title: "Robots All Around",
                description: "Meet robots in real life",
                thumbnailURL: nil,
                difficulty: 1,
                sourceURL: nil,
                aiAnalysis: nil,
                status: .published,
                sortOrder: 2,
                createdAt: Date(),
                publishedAt: Date(),
                cards: mockCardsForLesson(count: 5)
            ),
            Lesson(
                id: UUID(),
                pathId: learningPaths[1].id,
                userId: userId,
                title: "Computer Brains",
                description: "How does a computer 'think'?",
                thumbnailURL: nil,
                difficulty: 2,
                sourceURL: nil,
                aiAnalysis: nil,
                status: .published,
                sortOrder: 1,
                createdAt: Date(),
                publishedAt: Date(),
                cards: mockCardsForLesson(count: 5)
            ),
            Lesson(
                id: UUID(),
                pathId: learningPaths[1].id,
                userId: userId,
                title: "Learning Patterns",
                description: "Find patterns like a computer",
                thumbnailURL: nil,
                difficulty: 2,
                sourceURL: nil,
                aiAnalysis: nil,
                status: .published,
                sortOrder: 2,
                createdAt: Date(),
                publishedAt: Date(),
                cards: mockCardsForLesson(count: 5)
            ),
            Lesson(
                id: UUID(),
                pathId: learningPaths[2].id,
                userId: userId,
                title: "Ask Dashy Anything",
                description: "Have a conversation with AI",
                thumbnailURL: nil,
                difficulty: 2,
                sourceURL: nil,
                aiAnalysis: nil,
                status: .published,
                sortOrder: 1,
                createdAt: Date(),
                publishedAt: Date(),
                cards: mockCardsForLesson(count: 5)
            ),
            Lesson(
                id: UUID(),
                pathId: learningPaths[2].id,
                userId: userId,
                title: "Build Your AI Friend",
                description: "Create a simple AI assistant",
                thumbnailURL: nil,
                difficulty: 3,
                sourceURL: nil,
                aiAnalysis: nil,
                status: .published,
                sortOrder: 2,
                createdAt: Date(),
                publishedAt: Date(),
                cards: mockCardsForLesson(count: 5)
            ),
        ]

        // Set current lesson to first one
        currentLesson = allLessons.first
    }

    /// Generates mock cards for a lesson.
    private func mockCardsForLesson(count: Int) -> [Card] {
        let lessonId = UUID()
        var cards: [Card] = []

        for i in 0..<count {
            let cardType: Card.CardType = i % 2 == 0 ? .story : .concept

            let card = Card(
                id: UUID(),
                lessonId: lessonId,
                type: cardType,
                sortOrder: i,
                content: Card.CardContent(
                    title: "Card \(i + 1)",
                    narrativeText: cardType == .story
                        ? "Once upon a time, a curious child asked, 'How do computers learn?'" : nil,
                    explanation: cardType == .concept
                        ? "AI learns by looking at many examples and finding patterns." : nil
                ),
                voiceScript: cardType == .story
                    ? "Once upon a time, a curious child asked, How do computers learn?"
                    : "AI learns by looking at many examples and finding patterns."
            )
            cards.append(card)
        }

        return cards
    }

    /// Refreshes data.
    ///
    /// S11-05 introduced the `isLoading` toggle so the Home screen could
    /// surface `LoadingSkeletonView` during pull-to-refresh. S11-19 swaps
    /// the mock sleep for a real three-fan fetch when a router is present:
    /// paths + lessons + (optionally) progress, all in parallel. A nil
    /// router falls through to the mock path so previews stay green.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        guard let apiRouter else {
            // Preview / test path — the 400ms sleep is the skeleton's
            // visible-work beat when there's no network latency.
            try? await Task.sleep(nanoseconds: 400_000_000)
            loadMockData()
            return
        }

        do {
            async let pathsFetch = apiRouter.fetchPaths()
            async let lessonsFetch = apiRouter.fetchLessons(pathId: nil)
            let (paths, lessons) = try await (pathsFetch, lessonsFetch)

            self.learningPaths = paths
            self.allLessons = lessons
            // Featured lesson = first published lesson. When we ship
            // recommendation ranking (S12+) this becomes the top ranked
            // lesson for the current child.
            self.currentLesson = lessons.first
            // Fetch progress only if we know which child to ask for; if
            // auth hasn't selected a child yet, skip silently (the hero
            // card degrades to lesson-with-no-progress cleanly).
            if let childId {
                cachedProgress = try await apiRouter.fetchProgress(childId: childId)
            }
            self.loadError = nil
        } catch let error as APIError {
            self.loadError = error
        } catch {
            self.loadError = .custom(error.localizedDescription)
        }
    }

    /// Cached progress data for `progressPercentage` and related readers.
    /// Private because the shape is likely to shift as S12 stabilizes the
    /// progress reporting contract.
    private var cachedProgress: ProgressData?

    /// Selects a lesson to view.
    func selectLesson(_ lesson: Lesson) {
        currentLesson = lesson
    }

    /// Gets featured lesson for hero card (usually the current one).
    var featuredLesson: Lesson? {
        currentLesson
    }

    /// Overall learning progress [0, 1].
    ///
    /// When live data is attached, derives from `cachedProgress.interactions`
    /// — unique cards marked `.completed` divided by total cards visible in
    /// the fetched lessons. De-duplication matters because a child can
    /// re-view a card multiple times; counting raw interaction rows would
    /// inflate the ratio above 1.0 easily. When no router is attached,
    /// returns the 35% mock value so the hero ring doesn't read as empty
    /// in `#Preview`.
    var progressPercentage: Double {
        guard let progress = cachedProgress else { return 0.35 }
        let totalCards = allLessons.reduce(0) { $0 + ($1.cards?.count ?? 0) }
        guard totalCards > 0 else { return 0 }
        let completedCardIds = Set(
            progress.interactions
                .filter { $0.action == .completed }
                .map { $0.cardId }
        )
        return min(1.0, Double(completedCardIds.count) / Double(totalCards))
    }
}
