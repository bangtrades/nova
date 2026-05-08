import Foundation
import Combine
import Network
import NovaCore

/// Manages asset caching with WiFi-only preloading and LRU eviction.
///
/// Pre-downloads lesson images and audio to the Caches directory when on WiFi.
/// Provides cached URLs and automatically manages cache size with LRU eviction.
@MainActor
public class AssetCacheManager: NSObject, ObservableObject {
    /// Current download progress (0-1).
    @Published public var downloadProgress: Double = 0

    /// Whether currently downloading.
    @Published public var isDownloading: Bool = false

    /// Cache size in bytes.
    @Published public var cacheSize: Int64 = 0

    /// Error message from last operation.
    @Published public var lastError: String?

    /// Maximum cache size (500 MB).
    private let maxCacheSize: Int64 = 500 * 1024 * 1024

    /// Cache directory URL.
    private let cacheDirectory: URL

    /// File manager instance.
    private let fileManager = FileManager.default

    /// URL session for downloads.
    private let urlSession: URLSession

    /// Cache metadata: [remoteURL.absoluteString: (localPath, accessTime)]
    private var cacheMetadata: [String: (path: String, accessTime: Date)] = [:]
    private let cacheMetadataKey = "nova_asset_cache_metadata"

    /// Lock for thread-safe operations.
    private let lock = NSLock()

    // MARK: - Initialization

    public override init() {
        // Setup cache directory
        let cachesURL = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        self.cacheDirectory = cachesURL.appendingPathComponent("NovaAssets", isDirectory: true)

        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Setup URL session with reasonable timeouts
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600  // 1 hour
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config)

        super.init()
        loadCacheMetadata()
        updateCacheSize()
    }

    deinit {
        urlSession.invalidateAndCancel()
    }

    // MARK: - Public Methods

    /// Pre-downloads assets for a lesson when on WiFi.
    /// - Parameters:
    ///   - lessonId: The lesson ID.
    ///   - urls: Array of asset URLs to download.
    public func preloadAssets(for lessonId: String, urls: [URL]) async {
        // Check connectivity — WiFi only
        let onExpensiveNetwork = await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "ConnectivityCheck")
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.isExpensive)
            }
            monitor.start(queue: queue)
        }

        guard !onExpensiveNetwork else {
            lastError = "WiFi required for asset preload"
            return
        }

        isDownloading = true
        downloadProgress = 0
        lastError = nil

        let totalAssets = urls.count
        var successCount = 0

        for (index, url) in urls.enumerated() {
            do {
                _ = try await downloadAsset(url)
                successCount += 1
            } catch {
                // Log but continue with other assets
                print("Failed to download asset: \(url), error: \(error)")
            }

            // Update progress
            downloadProgress = Double(index + 1) / Double(totalAssets)
        }

        isDownloading = false

        if successCount == totalAssets {
            lastError = nil
        } else {
            lastError = "Downloaded \(successCount) of \(totalAssets) assets"
        }
    }

    /// Returns cached URL for a remote asset, or nil if not cached.
    /// - Parameter remoteURL: The remote asset URL.
    /// - Returns: Local file URL if cached, nil otherwise.
    public func cachedURL(for remoteURL: URL) -> URL? {
        lock.lock()
        defer { lock.unlock() }

        let key = remoteURL.absoluteString

        guard let metadata = cacheMetadata[key] else {
            return nil
        }

        // Update access time for LRU tracking
        cacheMetadata[key]?.accessTime = Date()

        return URL(fileURLWithPath: metadata.path)
    }

    /// Clears all cached assets.
    public func clearCache() {
        lock.lock()
        defer { lock.unlock() }

        do {
            try fileManager.removeItem(at: cacheDirectory)
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            cacheMetadata.removeAll()
            saveCacheMetadata()
            updateCacheSize()
        } catch {
            lastError = "Failed to clear cache: \(error.localizedDescription)"
        }
    }

    // MARK: - Private Methods

    private func downloadAsset(_ url: URL) async throws -> URL {
        // Check if already cached
        if let cached = cachedURL(for: url) {
            return cached
        }

        let fileName = url.lastPathComponent
        let localURL = cacheDirectory.appendingPathComponent(fileName)

        // Download the asset
        let (tempURL, _) = try await urlSession.download(from: url)

        // Move to cache
        try fileManager.moveItem(at: tempURL, to: localURL)

        // Update metadata (synchronous scope to keep NSLock out of async context)
        updateMetadata(key: url.absoluteString, path: localURL.path)

        // Check cache size and evict if needed
        updateCacheSize()
        evictLRUIfNeeded()

        return localURL
    }

    private func evictLRUIfNeeded() {
        var currentSize = calculateCacheSize()

        guard currentSize > maxCacheSize else { return }

        // Sort by access time (oldest first)
        let sorted = cacheMetadata.sorted { $0.value.accessTime < $1.value.accessTime }

        for (key, metadata) in sorted {
            if currentSize <= maxCacheSize {
                break
            }

            // Get file size BEFORE deleting
            let fileSize = (try? fileManager.attributesOfItem(atPath: metadata.path))?[.size] as? Int64 ?? 0

            do {
                try fileManager.removeItem(atPath: metadata.path)
                cacheMetadata.removeValue(forKey: key)
                currentSize -= fileSize
            } catch {
                print("Failed to evict cache file: \(error)")
            }
        }

        saveCacheMetadata()
    }

    private func calculateCacheSize() -> Int64 {
        var size: Int64 = 0

        if let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for url in contents {
                if let attributes = try? fileManager.attributesOfItem(atPath: url.path),
                   let fileSize = attributes[.size] as? Int64 {
                    size += fileSize
                }
            }
        }

        return size
    }

    private func updateCacheSize() {
        cacheSize = calculateCacheSize()
    }

    /// Updates metadata for a cached asset (synchronous scope for NSLock safety).
    private func updateMetadata(key: String, path: String) {
        lock.lock()
        defer { lock.unlock() }
        cacheMetadata[key] = (path: path, accessTime: Date())
        saveCacheMetadata()
    }

    private func loadCacheMetadata() {
        if let data = UserDefaults.standard.data(forKey: cacheMetadataKey),
           let decoded = try? JSONDecoder().decode(
               [String: CacheMetadataEntry].self,
               from: data
           ) {
            lock.lock()
            defer { lock.unlock() }

            for (key, entry) in decoded {
                cacheMetadata[key] = (path: entry.path, accessTime: entry.accessTime)
            }
        }
    }

    private func saveCacheMetadata() {
        let entries = cacheMetadata.mapValues { metadata in
            CacheMetadataEntry(path: metadata.path, accessTime: metadata.accessTime)
        }

        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: cacheMetadataKey)
        }
    }
}

/// Codable wrapper for cache metadata.
private struct CacheMetadataEntry: Codable {
    let path: String
    let accessTime: Date
}
