import Foundation

/// Protocol for entities that can be synced and may have conflicts.
///
/// Requires entities to have a unique ID, update timestamp, and sync version.
public protocol SyncableEntity {
    /// Unique identifier for the entity.
    func getSyncId() -> String

    /// Timestamp of the last update.
    func getSyncUpdatedAt() -> Date

    /// Sync version for conflict detection.
    func getSyncVersion() -> Int
}

/// Conflict resolution policy.
public enum ConflictPolicy {
    /// Server version always wins (for lesson content, paths, etc.).
    case serverWins

    /// Local version always wins (for progress, user interactions).
    case clientWins

    /// The version with the newer timestamp wins.
    case newerWins
}

/// Resolves synchronization conflicts between local and remote entities.
///
/// Implements conflict resolution strategies with logging for debugging.
public class ConflictResolver {
    /// Shared singleton instance.
    public static let shared = ConflictResolver()

    private init() {
        setupLogging()
    }

    /// Resolves a conflict between local and remote entities.
    ///
    /// - Parameters:
    ///   - local: The local entity.
    ///   - remote: The remote entity from the server.
    ///   - policy: The conflict resolution policy to apply.
    /// - Returns: The resolved entity to use.
    public func resolve<T: SyncableEntity>(
        local: T,
        remote: T,
        policy: ConflictPolicy
    ) -> T {
        logConflict(
            entity: local.getSyncId(),
            local: local,
            remote: remote,
            policy: policy
        )

        switch policy {
        case .serverWins:
            logResolution(entity: local.getSyncId(), winner: "server", policy: policy)
            return remote

        case .clientWins:
            logResolution(entity: local.getSyncId(), winner: "client", policy: policy)
            return local

        case .newerWins:
            let winner = local.getSyncUpdatedAt() >= remote.getSyncUpdatedAt() ? local : remote
            let winnerName = local.getSyncUpdatedAt() >= remote.getSyncUpdatedAt() ? "client" : "server"
            logResolution(entity: local.getSyncId(), winner: winnerName, policy: policy)
            return winner
        }
    }

    // MARK: - Default Policy Helpers

    /// Gets the default conflict policy for content entities.
    ///
    /// Content entities (Lesson, Card, LearningPath) use `.serverWins`.
    public static var contentPolicy: ConflictPolicy {
        return .serverWins
    }

    /// Gets the default conflict policy for progress entities.
    ///
    /// Progress entities use `.clientWins` (local interaction data is ground truth).
    public static var progressPolicy: ConflictPolicy {
        return .clientWins
    }

    // MARK: - Logging

    private let logDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private func setupLogging() {
        #if DEBUG
        print("[ConflictResolver] Initialized")
        #endif
    }

    private func logConflict<T: SyncableEntity>(
        entity: String,
        local: T,
        remote: T,
        policy: ConflictPolicy
    ) {
        #if DEBUG
        let timestamp = logDateFormatter.string(from: Date())
        print(
            """
            [\(timestamp)] [ConflictResolver] Conflict detected:
              Entity ID: \(entity)
              Local version: \(local.getSyncVersion()), updated: \(local.getSyncUpdatedAt())
              Remote version: \(remote.getSyncVersion()), updated: \(remote.getSyncUpdatedAt())
              Policy: \(policy)
            """
        )
        #endif
    }

    private func logResolution(
        entity: String,
        winner: String,
        policy: ConflictPolicy
    ) {
        #if DEBUG
        let timestamp = logDateFormatter.string(from: Date())
        print(
            """
            [\(timestamp)] [ConflictResolver] Conflict resolved:
              Entity ID: \(entity)
              Winner: \(winner)
              Policy: \(policy)
            """
        )
        #endif
    }
}

// MARK: - Entity Extensions

/// Extension to make common data models conform to SyncableEntity.
///
/// These are convenience implementations for the Nova app's core entities.

extension Lesson: SyncableEntity {
    /// Returns the lesson ID as a string.
    public func getSyncId() -> String {
        return id.uuidString
    }

    /// Returns the last update timestamp.
    public func getSyncUpdatedAt() -> Date {
        return publishedAt ?? createdAt
    }

    /// Returns a sync version (1 for MVP).
    public func getSyncVersion() -> Int {
        return 1
    }
}

extension Card: SyncableEntity {
    /// Returns the card ID as a string.
    public func getSyncId() -> String {
        return id.uuidString
    }

    /// Returns the last update timestamp.
    public func getSyncUpdatedAt() -> Date {
        return createdAt
    }

    /// Returns a sync version (1 for MVP).
    public func getSyncVersion() -> Int {
        return 1
    }
}

extension LearningPath: SyncableEntity {
    /// Returns the learning path ID as a string.
    public func getSyncId() -> String {
        return id.uuidString
    }

    /// Returns the last update timestamp.
    public func getSyncUpdatedAt() -> Date {
        return self.updatedAt
    }

    /// Returns a sync version (1 for MVP).
    public func getSyncVersion() -> Int {
        return 1
    }
}
