import Foundation
import Combine

/// Protocol for API routing operations.
///
/// Provides a common interface for making API requests.
public protocol APIRouting {
    /// Makes a request to an API endpoint.
    /// - Parameters:
    ///   - endpoint: The endpoint to request.
    /// - Returns: Decoded response of type T.
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}

/// Observable API router wrapping the APIClient.
///
/// Provides SwiftUI-friendly published properties and common API operations.
public class APIRouter: APIRouting, ObservableObject {
    /// Current authentication state.
    @Published public var isAuthenticated: Bool = false

    /// Currently logged-in user.
    @Published public var currentUser: User?

    /// Last error encountered.
    @Published public var lastError: APIError?

    /// Underlying API client.
    private let apiClient: APIClient

    /// Initialize a new APIRouter.
    /// - Parameters:
    ///   - apiClient: The APIClient to wrap.
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// Makes a request through the underlying API client.
    public func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        do {
            let result: T = try await apiClient.request(endpoint)
            lastError = nil
            return result
        } catch let error as APIError {
            lastError = error
            throw error
        }
    }

    // MARK: - Common Operations

    /// Fetches the current user's profile.
    @MainActor
    public func fetchProfile() async throws {
        let user: User = try await request(.getProfile())
        currentUser = user
        isAuthenticated = true
    }

    /// Fetches all learning paths for the user.
    @MainActor
    public func fetchPaths() async throws -> [LearningPath] {
        return try await request(.getPaths())
    }

    /// Fetches all child profiles for the user.
    @MainActor
    public func fetchChildren() async throws -> [ChildProfile] {
        return try await request(.getChildren())
    }

    /// Creates a new child profile.
    @MainActor
    public func createChild(_ profile: ChildProfile) async throws -> ChildProfile {
        return try await request(.createChild(profile))
    }

    /// Fetches a specific learning path.
    @MainActor
    public func fetchPath(id: UUID) async throws -> LearningPath {
        return try await request(.getPaths())
    }

    /// Creates a new learning path.
    @MainActor
    public func createPath(_ path: LearningPath) async throws -> LearningPath {
        return try await request(.createPath(path))
    }

    /// Fetches lessons for a specific path.
    @MainActor
    public func fetchLessons(pathId: UUID? = nil) async throws -> [Lesson] {
        return try await request(.getLessons(pathId: pathId))
    }

    /// Fetches a specific lesson.
    @MainActor
    public func fetchLesson(id: UUID) async throws -> Lesson {
        return try await request(.getLesson(id: id))
    }

    /// Creates a new lesson.
    @MainActor
    public func createLesson(_ lesson: Lesson) async throws -> Lesson {
        return try await request(.createLesson(lesson))
    }

    /// Publishes a lesson.
    @MainActor
    public func publishLesson(id: UUID) async throws {
        let _: EmptyResponse = try await request(.publishLesson(id: id))
    }

    /// Fetches cards for a lesson.
    @MainActor
    public func fetchCards(lessonId: UUID) async throws -> [Card] {
        return try await request(.getCards(lessonId: lessonId))
    }

    /// Syncs progress interactions to the server.
    @MainActor
    public func syncProgress(_ interactions: [CardInteraction]) async throws {
        let _: EmptyResponse = try await request(.syncProgress(interactions))
    }

    /// Gets progress for a child.
    @MainActor
    public func fetchProgress(childId: UUID) async throws -> ProgressData {
        return try await request(.getProgress(childId: childId))
    }

    /// Fetches all available badges.
    @MainActor
    public func fetchBadges() async throws -> [Badge] {
        return try await request(.getBadges())
    }

    /// Fetches badges earned by a child.
    @MainActor
    public func fetchEarnedBadges(childId: UUID) async throws -> [EarnedBadge] {
        return try await request(.getEarnedBadges(childId: childId))
    }

    /// Clears the current user and authentication state.
    @MainActor
    public func logout() {
        currentUser = nil
        isAuthenticated = false
        lastError = nil
    }
}

/// Empty response for endpoints that don't return data.
struct EmptyResponse: Decodable {}

/// Aggregated progress data for a child.
public struct ProgressData: Codable {
    /// Recent learning sessions.
    public var sessions: [LearningSession]

    /// Recent card interactions.
    public var interactions: [CardInteraction]

    /// Badges earned by the child.
    public var earnedBadges: [EarnedBadge]

    enum CodingKeys: String, CodingKey {
        case sessions
        case interactions
        case earnedBadges = "earned_badges"
    }
}
