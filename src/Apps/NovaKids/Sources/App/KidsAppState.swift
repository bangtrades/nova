import Foundation
import NovaCore
import NovaAuth

/// Shared application state for the Nova Kids app.
///
/// Holds the current lesson, path, and child profile selection,
/// and provides access to all managers.
public class KidsAppState: ObservableObject {
    /// Currently selected learning path.
    @Published public var selectedPath: LearningPath?

    /// Currently playing lesson.
    @Published public var currentLesson: Lesson?

    /// Current child profile.
    @Published public var currentChild: ChildProfile?

    /// All available learning paths.
    @Published public var learningPaths: [LearningPath] = []

    /// All child profiles for the user.
    @Published public var childProfiles: [ChildProfile] = []

    /// Authentication manager.
    public let authManager: AuthManager

    /// API router.
    public let apiRouter: APIRouter

    /// Sync manager.
    public let syncManager: SyncManager

    /// Initialize a new KidsAppState.
    /// - Parameters:
    ///   - authManager: The authentication manager.
    ///   - apiRouter: The API router.
    ///   - syncManager: The sync manager.
    public init(
        authManager: AuthManager,
        apiRouter: APIRouter,
        syncManager: SyncManager
    ) {
        self.authManager = authManager
        self.apiRouter = apiRouter
        self.syncManager = syncManager
    }

    /// Loads initial data (paths, children, etc.).
    @MainActor
    public func loadInitialData() async {
        do {
            learningPaths = try await apiRouter.fetchPaths()
            childProfiles = try await apiRouter.fetchChildren()

            // Select first child if available
            if let firstChild = childProfiles.first {
                currentChild = firstChild
            }

            // Select first path if available
            if let firstPath = learningPaths.first {
                selectedPath = firstPath
            }
        } catch {
            print("Failed to load initial data: \(error)")
        }
    }

    /// Selects a learning path.
    @MainActor
    public func selectPath(_ path: LearningPath) {
        selectedPath = path
        currentLesson = nil
    }

    /// Selects a lesson to play.
    @MainActor
    public func selectLesson(_ lesson: Lesson) {
        currentLesson = lesson
    }

    /// Clears the current lesson.
    @MainActor
    public func clearCurrentLesson() {
        currentLesson = nil
    }

    /// Resets all state (useful on logout).
    @MainActor
    public func reset() {
        selectedPath = nil
        currentLesson = nil
        currentChild = nil
        learningPaths = []
        childProfiles = []
    }
}
