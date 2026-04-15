import Foundation
import BackgroundTasks
import NovaCore

/// Manages background task scheduling and execution for sync and asset preloading.
///
/// Registers two background tasks on app launch:
/// 1. `com.nova.sync` (BGAppRefreshTask) — syncs new/updated lessons from server
/// 2. `com.nova.assets` (BGProcessingTask) — pre-downloads audio + images for new lessons
///
/// Uses singleton pattern with `shared` instance.
@MainActor
public class BackgroundTaskManager: NSObject, ObservableObject {
    /// Singleton instance.
    public static let shared = BackgroundTaskManager()

    /// Whether a sync task is currently running.
    @Published public var isSyncing: Bool = false

    /// Whether an asset download task is currently running.
    @Published public var isDownloadingAssets: Bool = false

    /// Last error from background operations.
    @Published public var lastError: String?

    /// Reference to sync manager for coordinating syncs.
    private weak var syncManager: SyncManager?

    /// Reference to asset cache manager for preloading.
    private weak var assetCacheManager: AssetCacheManager?

    override init() {
        super.init()
    }

    // MARK: - Setup

    /// Registers background tasks and sets up handlers.
    /// Call this in app init or application lifecycle method.
    public func setupBackgroundTasks(
        syncManager: SyncManager,
        assetCacheManager: AssetCacheManager
    ) {
        self.syncManager = syncManager
        self.assetCacheManager = assetCacheManager

        // Register sync task handler
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.nova.sync",
            using: nil
        ) { [weak self] task in
            self?.handleSyncTask(task as! BGAppRefreshTask)
        }

        // Register asset download task handler
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.nova.assets",
            using: nil
        ) { [weak self] task in
            self?.handleAssetTask(task as! BGProcessingTask)
        }

        // Schedule initial sync
        scheduleSync()

        // Schedule initial asset download
        scheduleAssetDownload()
    }

    // MARK: - Scheduling

    /// Schedules the next sync task (minimum 15 minutes from now).
    public func scheduleSync() {
        let request = BGAppRefreshTaskRequest(identifier: "com.nova.sync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            lastError = "Failed to schedule sync: \(error.localizedDescription)"
            print("Failed to schedule sync: \(error)")
        }
    }

    /// Schedules the next asset download task (minimum 1 hour from now).
    /// Requires network connectivity and external power.
    public func scheduleAssetDownload() {
        let request = BGProcessingTaskRequest(identifier: "com.nova.assets")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            lastError = "Failed to schedule asset download: \(error.localizedDescription)"
            print("Failed to schedule asset download: \(error)")
        }
    }

    // MARK: - Task Handlers

    /// Handles the sync background task.
    private func handleSyncTask(_ task: BGAppRefreshTask) {
        isSyncing = true

        // Set expiration handler
        task.expirationHandler = { [weak self] in
            self?.isSyncing = false
            task.setTaskCompleted(success: false)
        }

        // Perform sync
        Task { [weak self] in
            guard let self else {
                task.setTaskCompleted(success: false)
                return
            }

            guard let syncManager = self.syncManager else {
                // syncManager was deallocated — mark as failed, don't crash
                self.isSyncing = false
                self.lastError = "Sync manager unavailable"
                task.setTaskCompleted(success: false)
                self.scheduleSync()
                return
            }

            do {
                try await syncManager.fullSync()
                self.isSyncing = false
                self.lastError = nil
                task.setTaskCompleted(success: true)
            } catch {
                self.isSyncing = false
                self.lastError = error.localizedDescription
                task.setTaskCompleted(success: false)
            }

            // Schedule next sync
            self.scheduleSync()
        }
    }

    /// Handles the asset download background task.
    private func handleAssetTask(_ task: BGProcessingTask) {
        isDownloadingAssets = true

        // Set expiration handler
        task.expirationHandler = { [weak self] in
            self?.isDownloadingAssets = false
            task.setTaskCompleted(success: false)
        }

        // Perform asset preload
        Task { [weak self] in
            guard let self else {
                task.setTaskCompleted(success: false)
                return
            }

            do {
                guard !Task.isCancelled else {
                    self.isDownloadingAssets = false
                    task.setTaskCompleted(success: false)
                    return
                }

                // In real implementation, fetch new lessons and preload assets
                // For now, just simulate completion
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

                self.isDownloadingAssets = false
                self.lastError = nil
                task.setTaskCompleted(success: true)
            } catch {
                self.isDownloadingAssets = false
                self.lastError = error.localizedDescription
                task.setTaskCompleted(success: false)
            }

            // Schedule next asset download
            self.scheduleAssetDownload()
        }
    }

    // MARK: - Manual Triggers

    /// Manually trigger a sync attempt now.
    public func syncNow() {
        guard let syncManager else {
            lastError = "Sync manager unavailable"
            return
        }

        isSyncing = true

        Task {
            do {
                try await syncManager.fullSync()
                self.isSyncing = false
                self.lastError = nil
            } catch {
                self.isSyncing = false
                self.lastError = error.localizedDescription
            }
        }
    }

    /// Manually trigger asset download now.
    public func downloadAssetsNow() {
        isDownloadingAssets = true

        Task {
            do {
                guard !Task.isCancelled else {
                    self.isDownloadingAssets = false
                    return
                }
                // Placeholder for real asset download
                try await Task.sleep(nanoseconds: 500_000_000)
                self.isDownloadingAssets = false
                self.lastError = nil
            } catch {
                self.isDownloadingAssets = false
                self.lastError = error.localizedDescription
            }
        }
    }
}
