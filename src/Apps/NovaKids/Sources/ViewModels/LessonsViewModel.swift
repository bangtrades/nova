import Foundation
import NovaCore

/// ViewModel for the Lessons tab.
///
/// Manages lesson display, filtering by path, and completion tracking.
///
/// S11-19 wire-up: the VM keeps its zero-arg `init()` so every call site
/// (`@StateObject private var viewModel = LessonsViewModel()`) and every
/// `#Preview` continues to work without constructor-injection gymnastics.
/// The View passes `apiRouter` in via the idempotent `attach(apiRouter:)`
/// from inside a `.task`, where `@EnvironmentObject` is already available.
/// `refresh()` branches on `apiRouter == nil` — a nil router falls through
/// to the mock path, so previews stay green and unit tests don't require
/// a live backend.
@MainActor
public class LessonsViewModel: ObservableObject {
    @Published var allLessons: [Lesson] = []
    @Published var learningPaths: [LearningPath] = []
    @Published var selectedPath: LearningPath?
    @Published var isLoading: Bool = false
    /// Surfaced by the View as a small error banner above the grid. Cleared
    /// on a successful fetch. Typed `APIError?` (not `Error?`) so the View
    /// can render a semantic message via `errorDescription` without a cast.
    @Published var loadError: APIError?

    /// Injected after construction. Stays optional so previews and tests can
    /// exercise the mock path without wiring a router. `attach(_:)` is
    /// idempotent — repeat calls from `.task` (which fires on every view
    /// appear) are no-ops after the first.
    private var apiRouter: APIRouter?

    /// Initialize with mock data.
    public init() {
        loadMockData()
    }

    /// Wire the router in from the View's `.task`. Safe to call repeatedly.
    public func attach(apiRouter: APIRouter) {
        guard self.apiRouter == nil else { return }
        self.apiRouter = apiRouter
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

    /// Refreshes the lesson catalog.
    ///
    /// S11-14 wired the `isLoading` flag so `LessonsView` could surface
    /// `LoadingSkeletonView` during pull-to-refresh. S11-19 swaps the
    /// mock sleep for a real dual-fetch — paths and lessons in parallel
    /// via `async let` because they're independent GETs; we want the
    /// filter row to appear at the same time as the grid, not staggered.
    /// The `nil` router branch stays so previews + unit tests keep the
    /// visible-skeleton beat without a live backend.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        guard let apiRouter else {
            // Preview / test path — the 400ms sleep is what gives the
            // skeleton its visible-work beat when there's no network
            // latency to provide it. Delete this branch when mock data
            // is no longer needed for previews.
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
            self.loadError = nil
        } catch let error as APIError {
            self.loadError = error
        } catch {
            self.loadError = .custom(error.localizedDescription)
        }
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
