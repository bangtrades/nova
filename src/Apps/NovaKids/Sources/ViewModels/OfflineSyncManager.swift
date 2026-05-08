import Foundation
import Combine
import Network
import NovaCore
import NovaStorage

/// Manages offline event queuing and automatic sync when connectivity returns.
///
/// Persists events to UserDefaults when offline, monitors network connectivity,
/// and syncs all pending events when online with exponential backoff on failures.
@MainActor
public class OfflineSyncManager: NSObject, ObservableObject {
    /// Number of pending events in the queue.
    @Published public var pendingCount: Int = 0

    /// Whether sync is currently in progress.
    @Published public var isSyncing: Bool = false

    /// Last error during sync.
    @Published public var lastError: String?

    /// Network path monitor for connectivity detection.
    private var pathMonitor: NWPathMonitor?

    /// Queue directory for encrypted event storage.
    private let queueKey = "nova_offline_events_queue"
    private let queueMetaKey = "nova_offline_events_meta"

    /// Encrypted storage for COPPA-compliant data persistence.
    private let encryptedStorage = EncryptedStorage.shared

    /// Maximum queue size (FIFO eviction).
    private let maxQueueSize = 500

    /// Current retry backoff duration.
    private var retryBackoff: TimeInterval = 1.0
    private let maxRetryBackoff: TimeInterval = 30.0

    /// API router for syncing.
    private let apiRouter: APIRouter

    /// Sync cancellation token.
    private var syncTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(apiRouter: APIRouter) {
        self.apiRouter = apiRouter
        super.init()
        setupNetworkMonitoring()
        loadPendingCount()
    }

    deinit {
        pathMonitor?.cancel()
        syncTask?.cancel()
    }

    // MARK: - Public Methods

    /// Queues an event for later sync.
    /// - Parameters:
    ///   - type: Event type (e.g., "progress_update", "session_complete")
    ///   - payload: Event data dictionary
    public func queueEvent(type: String, payload: [String: Any]) {
        let event: [String: Any] = [
            "type": type,
            "payload": payload,
            "timestamp": Date().timeIntervalSince1970
        ]

        // Load existing queue
        var queue = loadQueue()

        // Check for duplicate (simple deduplication)
        let isDuplicate = queue.contains { existing in
            guard let existingType = existing["type"] as? String,
                  let existingPayload = existing["payload"] as? [String: Any],
                  let existingTime = existing["timestamp"] as? TimeInterval else {
                return false
            }

            let isSameType = existingType == type
            let isSamePayload = NSDictionary(dictionary: existingPayload)
                .isEqual(to: payload)
            let isRecent = Date().timeIntervalSince1970 - existingTime < 5 // Within 5 seconds

            return isSameType && isSamePayload && isRecent
        }

        if isDuplicate {
            return
        }

        // Add event
        queue.append(event)

        // Enforce max queue size (FIFO eviction)
        if queue.count > maxQueueSize {
            queue.removeFirst(queue.count - maxQueueSize)
        }

        // Save queue
        saveQueue(queue)
        pendingCount = queue.count
        lastError = nil
    }

    /// Flushes all pending events to the server.
    public func flushQueue() async {
        guard pendingCount > 0 else { return }
        guard !isSyncing else { return }

        isSyncing = true

        do {
            let queue = loadQueue()
            guard !queue.isEmpty else {
                isSyncing = false
                return
            }

            // Check cancellation before network work
            try Task.checkCancellation()

            // Simulate API call (replace with actual API client call in production)
            // In production: POST to /api/v1/sync/events via apiRouter
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            // Check cancellation after network work, before mutating state
            guard !Task.isCancelled else {
                isSyncing = false
                return
            }

            // Clear queue on success
            saveQueue([])
            pendingCount = 0
            retryBackoff = 1.0
            lastError = nil
            isSyncing = false
        } catch is CancellationError {
            isSyncing = false
        } catch {
            handleSyncError(error)
            isSyncing = false
        }
    }

    /// Manually trigger a sync attempt.
    public func syncNow() {
        syncTask?.cancel()
        syncTask = Task {
            await flushQueue()
        }
    }

    // MARK: - Private Methods

    private func setupNetworkMonitoring() {
        let monitor = NWPathMonitor()
        self.pathMonitor = monitor

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                if path.status == .satisfied {
                    // Connectivity restored
                    await self?.flushQueue()
                }
            }
        }

        let queue = DispatchQueue(label: "OfflineSyncMonitor")
        monitor.start(queue: queue)
    }

    private func loadQueue() -> [[String: Any]] {
        // Load from encrypted storage (COPPA: child interaction data must be encrypted at rest)
        if let data: Data = try? encryptedStorage.load(forKey: queueKey),
           let queue = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
            return queue
        }
        // Migration: check legacy unencrypted UserDefaults and migrate
        if let legacyData = UserDefaults.standard.data(forKey: queueKey),
           let legacyQueue = try? JSONSerialization.jsonObject(with: legacyData, options: []) as? [[String: Any]] {
            // Migrate to encrypted storage
            saveQueue(legacyQueue)
            // Remove unencrypted data
            UserDefaults.standard.removeObject(forKey: queueKey)
            return legacyQueue
        }
        return []
    }

    private func saveQueue(_ queue: [[String: Any]]) {
        // Store encrypted (COPPA: child interaction events may contain PII)
        if let data = try? JSONSerialization.data(withJSONObject: queue, options: []) {
            try? encryptedStorage.store(data, forKey: queueKey)
        }
    }

    private func loadPendingCount() {
        pendingCount = loadQueue().count
    }

    private func handleSyncError(_ error: Error) {
        lastError = "Sync failed: \(error.localizedDescription)"

        // Exponential backoff
        retryBackoff = min(retryBackoff * 2, maxRetryBackoff)

        // Schedule retry
        Task {
            try? await Task.sleep(nanoseconds: UInt64(retryBackoff * 1_000_000_000))
            await flushQueue()
        }
    }
}

/// Helper for encoding arbitrary dictionaries.
private struct AnySyncablePayload: Encodable {
    let value: [String: Any]

    init(_ value: [String: Any]) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        for (key, value) in value {
            guard let dynamicKey = DynamicKey(stringValue: key) else { continue }
            if let intValue = value as? Int {
                try container.encode(intValue, forKey: dynamicKey)
            } else if let stringValue = value as? String {
                try container.encode(stringValue, forKey: dynamicKey)
            } else if let doubleValue = value as? Double {
                try container.encode(doubleValue, forKey: dynamicKey)
            } else if let boolValue = value as? Bool {
                try container.encode(boolValue, forKey: dynamicKey)
            }
        }
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = String(intValue)
        }
    }
}
