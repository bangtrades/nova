import Foundation
import NovaCore

/// ViewModel for the Lessons tab.
///
/// Manages lesson display, filtering by path, and completion tracking.
@MainActor
public class LessonsViewModel: ObservableObject {
    @Published var allLessons: [Lesson] = []
    @Published var learningPaths: [LearningPath] = []
    @Published var selectedPath: LearningPath?
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
                cards: []
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
                cards: []
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
                cards: []
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
                cards: []
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
                cards: []
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
                cards: []
            ),
        ]
    }

    /// Gets filtered lessons based on selected path.
    var filteredLessons: [Lesson] {
        if let path = selectedPath {
            return allLessons.filter { $0.pathId == path.id }
        }
        return allLessons
    }

    /// Selects a learning path for filtering.
    func selectPath(_ path: LearningPath?) {
        selectedPath = path
    }

    /// Gets lesson count for a path.
    func lessonCount(for path: LearningPath) -> Int {
        allLessons.filter { $0.pathId == path.id }.count
    }

    /// Gets completion status for a lesson (mock: based on ID hash).
    func isLessonComplete(_ lesson: Lesson) -> Bool {
        lesson.id.hashValue % 3 == 0
    }
}
