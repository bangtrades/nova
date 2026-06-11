import Foundation
import NovaCore

/// Queues progress interactions when offline for later synchronization.
///
/// Persists interactions to a JSON file in the app's documents directory.
/// When connectivity is restored, the queue can be flushed to sync all data.
public class OfflineSyncQueue {
    /// Directory for storing the sync queue.
    private let queueDirectory: URL

    /// Name of the queue file.
    private static let queueFileName = "nova_sync_queue.json"

    /// File manager for I/O operations.
    private let fileManager = FileManager.default

    /// Lock for thread-safe operations.
    private let lock = NSLock()

    /// Maximum number of items in queue before forcing sync.
    private let maxQueueSize: Int

    /// Initialize a new OfflineSyncQueue.
    /// - Parameters:
    ///   - maxQueueSize: Maximum items before forcing sync (defaults to 1000).
    public init(maxQueueSize: Int = 1000) throws {
        self.maxQueueSize = maxQueueSize

        // Get documents directory
        guard let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            throw QueueError.directoryAccessFailed
        }

        queueDirectory = documentsURL.appendingPathComponent("NovaSync", isDirectory: true)

        // Create directory if needed
        if !fileManager.fileExists(atPath: queueDirectory.path) {
            try fileManager.createDirectory(at: queueDirectory, withIntermediateDirectories: true)
        }
    }

    /// Enqueues a card interaction for later synchronization.
    ///
    /// - Parameters:
    ///   - interaction: The card interaction to queue.
    public func enqueue(_ interaction: CardInteraction) throws {
        lock.lock()
        defer { lock.unlock() }

        // Load existing queue
        var queue = try loadQueue()

        // Add new interaction
        queue.append(interaction)

        // Save queue
        try saveQueue(queue)
    }

    /// Enqueues multiple interactions.
    ///
    /// - Parameters:
    ///   - interactions: Array of interactions to queue.
    public func enqueue(_ interactions: [CardInteraction]) throws {
        lock.lock()
        defer { lock.unlock() }

        // Load existing queue
        var queue = try loadQueue()

        // Add new interactions
        queue.append(contentsOf: interactions)

        // Save queue
        try saveQueue(queue)
    }

    /// Flushes the queue by syncing all pending interactions to the server.
    ///
    /// - Parameters:
    ///   - apiRouter: The API router to use for syncing.
    ///   - childId: The child whose interactions these are — required
    ///     by the backend's syncProgressSchema (contract fix, Jun 10).
    /// - Throws: QueueError or APIError if sync fails.
    public func flush(using apiRouter: APIRouting, childId: UUID) async throws {
        // Read queue synchronously to avoid NSLock in async context
        let queue: [CardInteraction] = readQueueSynchronously()

        if queue.isEmpty {
            return
        }

        // Sync to server (EmptyResponse provides the generic type)
        struct FlushResponse: Decodable {}
        let _: FlushResponse = try await apiRouter.request(.syncProgress(childId: childId, queue))

        // Clear the queue on success (synchronous lock scope)
        clearQueueSynchronously()
    }

    /// Thread-safe synchronous read — keeps NSLock out of async context.
    private func readQueueSynchronously() -> [CardInteraction] {
        lock.lock()
        defer { lock.unlock() }
        return (try? loadQueue()) ?? []
    }

    /// Thread-safe synchronous clear — keeps NSLock out of async context.
    private func clearQueueSynchronously() {
        lock.lock()
        defer { lock.unlock() }
        try? saveQueue([])
    }

    /// Number of pending items in the queue.
    public var pendingCount: Int {
        lock.lock()
        defer { lock.unlock() }

        do {
            let queue = try loadQueue()
            return queue.count
        } catch {
            return 0
        }
    }

    /// Whether the queue has reached the maximum size.
    public var isAtCapacity: Bool {
        return pendingCount >= maxQueueSize
    }

    /// Clears all pending interactions from the queue.
    ///
    /// - Throws: QueueError if deletion fails.
    public func clear() throws {
        lock.lock()
        defer { lock.unlock() }

        let queuePath = queueDirectory.appendingPathComponent(Self.queueFileName).path
        if fileManager.fileExists(atPath: queuePath) {
            try fileManager.removeItem(atPath: queuePath)
        }
    }

    // MARK: - Private Methods

    private func loadQueue() throws -> [CardInteraction] {
        let queuePath = queueDirectory.appendingPathComponent(Self.queueFileName)

        guard fileManager.fileExists(atPath: queuePath.path) else {
            return []
        }

        let data = try Data(contentsOf: queuePath)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode([CardInteraction].self, from: data)
    }

    private func saveQueue(_ queue: [CardInteraction]) throws {
        let queuePath = queueDirectory.appendingPathComponent(Self.queueFileName)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(queue)
        try data.write(to: queuePath, options: .atomic)
    }
}

/// Errors that can occur during queue operations.
public enum QueueError: LocalizedError {
    /// Failed to access the queue directory.
    case directoryAccessFailed

    /// Failed to encode/decode queue data.
    case serializationFailed(Error)

    /// Failed to write queue to disk.
    case writeFailed(Error)

    /// Failed to read queue from disk.
    case readFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .directoryAccessFailed:
            return "Failed to access queue directory"
        case .serializationFailed(let error):
            return "Failed to serialize queue: \(error.localizedDescription)"
        case .writeFailed(let error):
            return "Failed to write queue: \(error.localizedDescription)"
        case .readFailed(let error):
            return "Failed to read queue: \(error.localizedDescription)"
        }
    }
}
