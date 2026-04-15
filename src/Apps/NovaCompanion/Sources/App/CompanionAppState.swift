import Foundation
import NovaCore
import NovaAuth

/// Shared application state for the Nova Companion app.
///
/// Holds the currently selected lesson for editing, card editing state,
/// and provides access to all managers for content creation.
public class CompanionAppState: ObservableObject {
    /// Currently selected lesson for editing.
    @Published public var selectedLesson: Lesson?

    /// Whether a card is currently being edited.
    @Published public var isEditingCard: Bool = false

    /// Currently selected/editing card.
    @Published public var editingCard: Card?

    /// All learning paths for the user.
    @Published public var learningPaths: [LearningPath] = []

    /// All lessons across all paths.
    @Published public var allLessons: [Lesson] = []

    /// Child profiles for progress tracking.
    @Published public var childProfiles: [ChildProfile] = []

    /// Authentication manager.
    public let authManager: AuthManager

    /// API router.
    public let apiRouter: APIRouter

    /// Sync manager.
    public let syncManager: SyncManager

    /// Initialize a new CompanionAppState.
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

    /// Loads initial data (paths, lessons, children).
    @MainActor
    public func loadInitialData() async {
        do {
            learningPaths = try await apiRouter.fetchPaths()
            allLessons = try await apiRouter.fetchLessons()
            childProfiles = try await apiRouter.fetchChildren()
        } catch {
            print("Failed to load initial data: \(error)")
        }
    }

    /// Selects a lesson for editing.
    @MainActor
    public func selectLessonForEditing(_ lesson: Lesson) {
        selectedLesson = lesson
        isEditingCard = false
        editingCard = nil
    }

    /// Starts editing a card.
    @MainActor
    public func startEditingCard(_ card: Card) {
        editingCard = card
        isEditingCard = true
    }

    /// Saves the currently editing card.
    @MainActor
    public func saveEditingCard() async {
        guard let card = editingCard else { return }

        do {
            let _: Card = try await apiRouter.request(.updateCard(id: card.id, card))

            // Update local lesson
            if let lessonIndex = allLessons.firstIndex(where: { $0.id == card.lessonId }) {
                // In production, update the card in the lesson
                selectedLesson = allLessons[lessonIndex]
            }

            isEditingCard = false
            editingCard = nil
        } catch {
            print("Failed to save card: \(error)")
        }
    }

    /// Cancels card editing without saving.
    @MainActor
    public func cancelEditingCard() {
        isEditingCard = false
        editingCard = nil
    }

    /// Creates a new lesson in a path.
    @MainActor
    public func createLesson(_ lesson: Lesson) async {
        do {
            let created: Lesson = try await apiRouter.request(.createLesson(lesson))
            allLessons.append(created)
            selectedLesson = created
        } catch {
            print("Failed to create lesson: \(error)")
        }
    }

    /// Publishes a lesson.
    @MainActor
    public func publishLesson(_ lessonId: UUID) async {
        do {
            try await apiRouter.publishLesson(id: lessonId)

            // Update local lesson status
            if let index = allLessons.firstIndex(where: { $0.id == lessonId }) {
                allLessons[index].status = .published
                selectedLesson = allLessons[index]
            }
        } catch {
            print("Failed to publish lesson: \(error)")
        }
    }

    /// Resets all state (useful on logout).
    @MainActor
    public func reset() {
        selectedLesson = nil
        editingCard = nil
        isEditingCard = false
        learningPaths = []
        allLessons = []
        childProfiles = []
    }
}
