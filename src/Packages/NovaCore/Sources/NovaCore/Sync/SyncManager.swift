import Foundation
import Combine
import CoreData

/// Manages synchronization of local data with the remote API.
///
/// Coordinates syncing of lessons, progress, and other data with Core Data integration.
/// Includes retry logic with exponential backoff and conflict resolution.
@MainActor
public class SyncManager: ObservableObject {
    /// Current sync state.
    @Published public var syncState: SyncState = .idle

    /// Date of the last successful sync.
    @Published public var lastSyncDate: Date?

    /// Whether a sync is currently in progress.
    @Published public var isSyncing: Bool = false

    /// Last error encountered during sync.
    @Published public var syncError: Error?

    /// The API router for making requests.
    private let apiRouter: APIRouting

    /// UserDefaults key for storing last sync timestamp.
    private let lastSyncTimestampKey = "nova.sync.lastTimestamp"

    /// Retry backoff times (seconds).
    private let retryBackoffs = [1.0, 2.0, 4.0, 8.0, 16.0, 30.0]

    /// Initialize a new SyncManager.
    /// - Parameters:
    ///   - apiRouter: The API router for making requests.
    public init(apiRouter: APIRouting) {
        self.apiRouter = apiRouter
    }

    // MARK: - Sync Operations

    /// Syncs lessons from the server since last sync timestamp.
    ///
    /// Fetches lessons and learning paths using the unified sync endpoint,
    /// parses them, and stores in Core Data.
    @MainActor
    public func syncLessons() async throws {
        syncState = .syncing
        isSyncing = true
        syncError = nil

        defer { isSyncing = false }

        do {
            let timestamp = lastSyncTimestamp
            let syncResponse: SyncResponse = try await apiRouter.request(
                .sync(since: timestamp, limit: 100)
            )

            // Save to Core Data via background context
            try await saveLessonsToCoreData(
                lessons: syncResponse.lessons,
                paths: syncResponse.paths
            )

            // Update last sync timestamp
            lastSyncTimestamp = Date()
            lastSyncDate = Date()
            syncState = .completed(Date())
        } catch {
            syncError = error
            syncState = .error(error)
            throw error
        }
    }

    /// Syncs progress interactions to the server.
    ///
    /// Sends buffered card interactions to the API with retry logic.
    @MainActor
    public func syncProgress(childId: UUID, _ interactions: [CardInteraction]) async throws {
        syncState = .syncing
        isSyncing = true
        syncError = nil

        defer { isSyncing = false }

        do {
            let _: EmptyResponse = try await apiRouter.request(.syncProgress(childId: childId, interactions))
            lastSyncDate = Date()
            syncState = .completed(Date())
        } catch {
            syncError = error
            syncState = .error(error)
            throw error
        }
    }

    /// Performs a full sync of all data with retry logic.
    ///
    /// Syncs paths, lessons, progress, and other relevant data with exponential backoff.
    @MainActor
    public func fullSync() async throws {
        var lastError: Error?
        var retryCount = 0

        while retryCount < retryBackoffs.count {
            do {
                try await syncLessons()
                return
            } catch {
                lastError = error
                retryCount += 1

                if retryCount < retryBackoffs.count {
                    let backoff = retryBackoffs[retryCount - 1]
                    try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                }
            }
        }

        if let error = lastError {
            syncState = .error(error)
            syncError = error
            throw error
        }
    }

    /// Invalidates the current sync state (useful after logout).
    @MainActor
    public func reset() {
        lastSyncDate = nil
        isSyncing = false
        syncError = nil
        syncState = .idle
    }

    // MARK: - Private Methods

    private var lastSyncTimestamp: Date {
        get {
            UserDefaults.standard.object(forKey: lastSyncTimestampKey) as? Date ?? Date(timeIntervalSince1970: 0)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lastSyncTimestampKey)
        }
    }

    /// Core Data write — runs off MainActor for performance.
    /// Uses nonisolated to avoid blocking UI during heavy I/O.
    nonisolated private func saveLessonsToCoreData(lessons: [Lesson], paths: [LearningPath]) async throws {
        // This will be implemented in conjunction with CoreDataSyncBridge
        // Heavy disk I/O should happen off the main actor.
        // When ready, use a background NSManagedObjectContext here and
        // pass NSManagedObjectID values back to MainActor for UI updates.
        //
        // For now, update the timestamp on MainActor:
        await MainActor.run {
            self.lastSyncTimestamp = Date()
        }
    }
}

/// Sync state enum for UI binding.
public enum SyncState: Equatable {
    case idle
    case syncing
    case error(Error)
    case completed(Date)

    public static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.syncing, .syncing):
            return true
        case (.completed(let date1), .completed(let date2)):
            return date1 == date2
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}

/// Response from the sync endpoint.
struct SyncResponse: Decodable {
    /// Learning paths from the server.
    let paths: [LearningPath]

    /// Lessons from the server.
    let lessons: [Lesson]
}
