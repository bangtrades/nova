import Foundation

/// Caches downloaded images and audio files to reduce bandwidth and improve load times.
///
/// Uses the app's caches directory for storage with LRU (Least Recently Used)
/// eviction when the cache exceeds the maximum size limit.
public class AssetCache {
    /// Default maximum cache size (100 MB).
    public static let defaultMaxSize: Int64 = 100 * 1024 * 1024

    /// Directory for storing cached assets.
    private let cacheDirectory: URL

    /// Maximum size of the cache in bytes.
    private let maxSize: Int64

    /// File manager for I/O operations.
    private let fileManager = FileManager.default

    /// Lock for thread-safe operations.
    private let lock = NSLock()

    /// Initialize a new AssetCache.
    /// - Parameters:
    ///   - maxSize: Maximum cache size in bytes (defaults to 100 MB).
    public init(maxSize: Int64 = defaultMaxSize) throws {
        self.maxSize = maxSize

        // Create caches directory path
        guard let cachesURL = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else {
            throw CacheError.directoryAccessFailed
        }

        cacheDirectory = cachesURL.appendingPathComponent("NovaAssets", isDirectory: true)

        // Create directory if needed
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }

    /// Caches an asset (image or audio file).
    ///
    /// - Parameters:
    ///   - url: The source URL (used to generate a cache key).
    ///   - data: The asset data to cache.
    /// - Throws: CacheError if caching fails.
    public func cacheAsset(url: URL, data: Data) throws {
        lock.lock()
        defer { lock.unlock() }

        let fileName = hashURLToFileName(url)
        let filePath = cacheDirectory.appendingPathComponent(fileName)

        // Write the file
        try data.write(to: filePath, options: .atomic)

        // Check if we need to evict
        let currentSize = try cacheSize()
        if currentSize > maxSize {
            try evictLRU()
        }
    }

    /// Retrieves a cached asset.
    ///
    /// - Parameters:
    ///   - url: The source URL to look up.
    /// - Returns: The cached asset data, or nil if not found or expired.
    public func getCachedAsset(url: URL) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        let fileName = hashURLToFileName(url)
        let filePath = cacheDirectory.appendingPathComponent(fileName)

        guard fileManager.fileExists(atPath: filePath.path) else {
            return nil
        }

        // Update access time by touching the file
        try? fileManager.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: filePath.path
        )

        return try? Data(contentsOf: filePath)
    }

    /// Clears all cached assets.
    ///
    /// - Throws: CacheError if deletion fails.
    public func clearCache() throws {
        lock.lock()
        defer { lock.unlock() }

        try fileManager.removeItem(at: cacheDirectory)
        try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Gets the current size of the cache.
    ///
    /// - Returns: Cache size in bytes.
    /// - Throws: CacheError if directory access fails.
    public func cacheSize() throws -> Int64 {
        lock.lock()
        defer { lock.unlock() }

        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var size: Int64 = 0
        for case let file as URL in enumerator {
            let attributes = try fileManager.attributesOfItem(atPath: file.path)
            if let fileSize = attributes[.size] as? Int64 {
                size += fileSize
            }
        }

        return size
    }

    // MARK: - Private Methods

    /// Generates a cache file name from a URL using hashing.
    private func hashURLToFileName(_ url: URL) -> String {
        let urlString = url.absoluteString
        // Use MD5 or SHA256 hash of the URL
        let data = urlString.data(using: .utf8) ?? Data()
        return data.hashValue.description + ".cache"
    }

    /// Evicts least recently used items until cache is under the limit.
    private func evictLRU() throws {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return
        }

        var files: [(url: URL, date: Date, size: Int64)] = []

        for case let file as URL in enumerator {
            let attributes = try fileManager.attributesOfItem(atPath: file.path)

            if let date = attributes[.modificationDate] as? Date,
               let size = attributes[.size] as? Int64 {
                files.append((url: file, date: date, size: size))
            }
        }

        // Sort by access time (oldest first)
        files.sort { $0.date < $1.date }

        // Delete oldest files until under limit
        var currentSize = try cacheSize()
        for file in files {
            if currentSize <= maxSize {
                break
            }

            try fileManager.removeItem(at: file.url)
            currentSize -= file.size
        }
    }
}

/// Errors that can occur during cache operations.
public enum CacheError: LocalizedError {
    /// Failed to access the cache directory.
    case directoryAccessFailed

    /// Failed to write to cache.
    case writeFailed(Error)

    /// Failed to read from cache.
    case readFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .directoryAccessFailed:
            return "Failed to access cache directory"
        case .writeFailed(let error):
            return "Failed to write cache: \(error.localizedDescription)"
        case .readFailed(let error):
            return "Failed to read cache: \(error.localizedDescription)"
        }
    }
}
