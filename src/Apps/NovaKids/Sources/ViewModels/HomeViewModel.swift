import Foundation
import NovaCore

/// ViewModel for the Home screen.
///
/// Manages the display of featured lessons, current progress, and learning paths.
@MainActor
public class HomeViewModel: ObservableObject {
    @Published var childName: String = "Explorer"
    @Published var currentLesson: Lesson?
    @Published var learningPaths: [LearningPath] = []
    @Published var allLessons: [Lesson] = []
    @Published var isLoading: Bool = false

    /// Initialize with mock data.
    public init() {
        loadMockData()
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

    /// Refreshes data (reloads mock data for now).
    ///
    /// As of S11-05 this toggles `isLoading` around the fetch so the Home
    /// screen can surface `LoadingSkeletonView` while the refresh is in
    /// flight — closes the S11-AUDIT finding #4 on the Home side. The
    /// 400ms sleep is intentional: the mock path resolves too quickly for
    /// the skeleton to even render, and pull-to-refresh feels broken
    /// without at least a moment of visible work. When this swaps to a
    /// real backend fetch, delete the sleep — the network latency will
    /// supply the signal instead.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        try? await Task.sleep(nanoseconds: 400_000_000)
        loadMockData()
    }

    /// Selects a lesson to view.
    func selectLesson(_ lesson: Lesson) {
        currentLesson = lesson
    }

    /// Gets featured lesson for hero card (usually the current one).
    var featuredLesson: Lesson? {
        currentLesson
    }

    /// Gets learning progress (mock: 35% complete).
    var progressPercentage: Double {
        0.35
    }
}
