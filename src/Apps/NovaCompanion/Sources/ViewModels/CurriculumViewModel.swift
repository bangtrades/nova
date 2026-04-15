import Foundation
import SwiftUI
import NovaCore

/// ViewModel for managing learning paths and curriculum.
public class CurriculumViewModel: NSObject, ObservableObject {
    @Published var paths: [LearningPath] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var apiRouter: APIRouter?

    public override init() {
        super.init()
        loadMockData()
    }

    /// Load all learning paths from API
    public func loadPaths(apiRouter: APIRouter? = nil) {
        if let apiRouter = apiRouter {
            self.apiRouter = apiRouter
        }

        isLoading = true
        error = nil

        Task {
            do {
                // In production: let paths = try await apiRouter?.fetch(Endpoint.getPaths())
                // For now, mock data is already loaded
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    /// Create a new learning path
    public func createPath(name: String, stage: String) {
        let stageEnum: ChildProfile.Stage = {
            switch stage.lowercased() {
            case "thinker":
                return .thinker
            case "maker":
                return .maker
            case "creator":
                return .creator
            default:
                return .explorer
            }
        }()

        let newPath = LearningPath(
            id: UUID(),
            userId: UUID(),
            title: name,
            description: "",
            color: "#000000",
            icon: "book.fill",
            sortOrder: paths.count,
            stage: stageEnum,
            isPremium: false,
            lessons: nil
        )

        paths.append(newPath)
    }

    /// Delete a learning path
    public func deletePath(id: UUID) {
        paths.removeAll { $0.id == id }
    }

    /// Reorder paths
    public func reorderPaths(from source: IndexSet, to destination: Int) {
        paths.move(fromOffsets: source, toOffset: destination)

        // Update sort order
        for (index, _) in paths.enumerated() {
            paths[index].sortOrder = index
        }
    }

    private func loadMockData() {
        paths = [
            LearningPath(
                id: UUID(),
                userId: UUID(),
                title: "How Computers Think",
                description: "Introduction to basic computer concepts",
                color: "#3B82F6",
                icon: "book.fill",
                sortOrder: 0,
                stage: .explorer,
                isPremium: false,
                lessons: nil
            ),
            LearningPath(
                id: UUID(),
                userId: UUID(),
                title: "Robot Adventures",
                description: "Explore robotics and automation",
                color: "#F97316",
                icon: "book.fill",
                sortOrder: 1,
                stage: .thinker,
                isPremium: false,
                lessons: nil
            ),
            LearningPath(
                id: UUID(),
                userId: UUID(),
                title: "Internet Explorers",
                description: "Learn about networks and the internet",
                color: "#A855F7",
                icon: "book.fill",
                sortOrder: 2,
                stage: .maker,
                isPremium: false,
                lessons: nil
            ),
        ]
    }
}

// MARK: - View Model Extensions

/// Extension to track display properties not in core model
extension LearningPath {
    /// Computed property for lesson count (would come from backend in production)
    var lessonCount: Int {
        lessons?.count ?? 0
    }

    /// Computed property for completion percentage (would come from backend in production)
    var completionPercentage: Int {
        0 // Placeholder - would be computed from progress data
    }

    /// Stage as a string for display
    var stageString: String {
        stage.displayName
    }

    /// Stage badge color
    var stageColor: Color {
        CompanionPalette.pathColor(for: stage.displayName)
    }
}

// MARK: - Preview Mock

#if DEBUG
extension CurriculumViewModel {
    static let preview = CurriculumViewModel()
}
#endif
