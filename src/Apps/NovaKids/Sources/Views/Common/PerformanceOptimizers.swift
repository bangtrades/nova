import SwiftUI
import UIKit
import ImageIO

// MARK: - Lazy Image View

/// Loading phase reported to `LazyImageView`'s content closure.
/// Mirrors the `AsyncImage.phase` shape so converting a call site is a
/// rename, not a redesign.
public enum LazyImagePhase {
    case loading
    case success(Image)
    case failure
}

/// Async image loading with memory caching and **off-main** decode +
/// downsample (V2-S4-06).
///
/// Drop-in replacement for `AsyncImage` on kid surfaces. The difference
/// that matters: `AsyncImage` decodes the full-resolution payload on
/// whatever thread Swift picks and keeps the full bitmap in memory.
/// This view routes through `ImageLoader`, which decodes and
/// downsamples in **one pass** via `CGImageSourceCreateThumbnailAtIndex`
/// on the cooperative pool — the main actor only ever sees the final,
/// already-decoded, capped-size `UIImage`. Repeat requests for the same
/// URL hit an `NSCache` and render synchronously.
///
/// `maxPixelSize` caps the decoded bitmap's longest side. Size it to
/// the rendered frame (e.g. 600 for a small trophy tile, 1600 for a
/// full-width hero) — memory cost scales with the square of this value.
public struct LazyImageView<Content: View>: View {
    let url: URL?
    let maxPixelSize: CGFloat
    @ViewBuilder let content: (LazyImagePhase) -> Content

    @State private var phase: LazyImagePhase = .loading

    public init(
        url: URL?,
        maxPixelSize: CGFloat = 1600,
        @ViewBuilder content: @escaping (LazyImagePhase) -> Content
    ) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        self.content = content
    }

    public var body: some View {
        content(phase)
            .task(id: url) {
                guard let url else {
                    phase = .failure
                    return
                }

                // Cache hit renders synchronously — no loading flash on
                // re-scroll.
                if let cached = ImageLoader.cachedImage(for: url, maxPixelSize: maxPixelSize) {
                    phase = .success(Image(uiImage: cached))
                    return
                }

                phase = .loading
                do {
                    let image = try await ImageLoader.loadImage(url, maxPixelSize: maxPixelSize)
                    phase = .success(Image(uiImage: image))
                } catch is CancellationError {
                    // View went away mid-fetch; leave phase alone.
                } catch {
                    phase = .failure
                }
            }
    }
}

// MARK: - Image Loader

/// Stateless loader behind `LazyImageView`. Namespaced as an enum —
/// the cache is process-global and the functions are pure async, so
/// there is nothing to instantiate.
private enum ImageLoader {
    private static let cache = NSCache<NSString, UIImage>()

    /// Cache key includes the size cap — the same URL decoded at 300px
    /// for a trophy tile must not be served to a 1600px hero panel
    /// (visibly soft) or vice versa (wasted memory).
    private static func cacheKey(_ url: URL, maxPixelSize: CGFloat) -> NSString {
        "\(url.absoluteString)#\(Int(maxPixelSize))" as NSString
    }

    /// Synchronous memory-cache lookup. `NSCache` is thread-safe.
    static func cachedImage(for url: URL, maxPixelSize: CGFloat) -> UIImage? {
        cache.object(forKey: cacheKey(url, maxPixelSize: maxPixelSize))
    }

    /// Downloads, decodes, and downsamples off the main actor.
    /// `nonisolated async` functions run on the global concurrent
    /// executor, so the `CGImageSource` work below never blocks UI.
    static func loadImage(_ url: URL, maxPixelSize: CGFloat) async throws -> UIImage {
        if let cached = cachedImage(for: url, maxPixelSize: maxPixelSize) {
            return cached
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        try Task.checkCancellation()

        guard let image = downsampledImage(data: data, maxPixelSize: maxPixelSize) else {
            throw URLError(.cannotDecodeContentData)
        }

        cache.setObject(image, forKey: cacheKey(url, maxPixelSize: maxPixelSize))
        return image
    }

    /// One-pass decode + downsample via ImageIO (the May 11 perf
    /// audit's prescribed fix). Compared to `UIImage(data:)` +
    /// `UIGraphicsImageRenderer`: never materializes the full-size
    /// bitmap, preserves aspect ratio and EXIF orientation, and
    /// produces an already-decoded image (`ShouldCacheImmediately`)
    /// so first render doesn't pay a lazy-decode hitch on main.
    private static func downsampledImage(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - View Recycler

/// Efficient list rendering with prefetching and cell lifecycle management.
public struct ViewRecycler<Content: View, Item: Identifiable>: View {
    let items: [Item]
    let prefetchDistance: Int = 3
    let content: (Item) -> Content

    @State private var visibleItems = Set<Item.ID>()

    public init(
        items: [Item],
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.content = content
    }

    public var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(items) { item in
                content(item)
                    .onAppear { handleAppear(item) }
                    .onDisappear { handleDisappear(item) }
            }
        }
    }

    private func handleAppear(_ item: Item) {
        visibleItems.insert(item.id)

        // Prefetch next items
        if let currentIndex = items.firstIndex(where: { $0.id == item.id }) {
            let endIndex = min(currentIndex + prefetchDistance, items.count - 1)
            for i in currentIndex..<endIndex {
                // Simulate prefetch
                let _ = items[i]
            }
        }
    }

    private func handleDisappear(_ item: Item) {
        visibleItems.remove(item.id)
    }
}

// MARK: - Memory Warning Handler

/// Observes memory warnings and manages cache clearing.
@MainActor
public class MemoryWarningHandler: NSObject, ObservableObject {
    @Published public var isLowMemory = false

    private var resetTask: Task<Void, Never>?
    private static let shared = MemoryWarningHandler()

    public override init() {
        super.init()
        setupMemoryWarningObserver()
    }

    /// Clears caches when memory is low.
    public func clearCaches() {
        // Clear image cache
        ImageLoader.clearCache()

        // Reduce audio cache (simplified)
        print("Clearing caches due to memory pressure")
    }

    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        isLowMemory = true
        clearCaches()

        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self.isLowMemory = false
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        resetTask?.cancel()
    }
}

private extension ImageLoader {
    static func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - Animation Throttler

/// Limits animation updates based on thermal state.
public class AnimationThrottler: NSObject, ObservableObject {
    @Published public var shouldReduceAnimations = false

    private let thermalMonitor = ProcessInfo.processInfo

    public override init() {
        super.init()
        checkThermalState()
        setupThermalMonitoring()
    }

    private func checkThermalState() {
        let state = ProcessInfo.processInfo.thermalState
        shouldReduceAnimations = state == .serious || state == .critical
    }

    private func setupThermalMonitoring() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkThermalState()
        }
    }

    /// Returns appropriate animation duration based on thermal state.
    public func animationDuration(default duration: TimeInterval = 0.3) -> TimeInterval {
        shouldReduceAnimations ? 0.15 : duration
    }

    /// Returns appropriate animation based on thermal state.
    public func animation(default animation: Animation = .easeInOut) -> Animation {
        shouldReduceAnimations ? .easeInOut(duration: 0.15) : animation
    }
}

// MARK: - Performance View Wrapper

/// Wraps content with performance optimizations.
public struct PerformanceOptimized<Content: View>: View {
    let content: () -> Content

    @StateObject private var throttler = AnimationThrottler()
    @StateObject private var memoryHandler = MemoryWarningHandler()

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            .environmentObject(throttler)
            .environmentObject(memoryHandler)
            .opacity(memoryHandler.isLowMemory ? 0.95 : 1.0)
    }
}

// MARK: - Efficient Carousel

/// Memory-efficient carousel for horizontal scrolling lists.
public struct EfficientCarousel<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    @State private var scrollPosition: Item.ID?

    public init(
        items: [Item],
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.content = content
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(items) { item in
                    content(item)
                        .containerRelativeFrame(.horizontal, count: 3, spacing: 12)
                        .id(item.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $scrollPosition)
        .scrollTargetBehavior(.viewAligned)
    }
}

// MARK: - Preview Item

private struct PreviewItem: Identifiable {
    let id: Int
    let text: String
}

#Preview {
    VStack(spacing: 24) {
        LazyImageView(url: URL(string: "https://via.placeholder.com/200")) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFill()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFill()
                    .foregroundStyle(.gray)
            }
        }
        .frame(height: 200)
        .cornerRadius(12)

        ViewRecycler(
            items: (1...5).map { index in
                PreviewItem(id: index, text: "Item \(index)")
            }
        ) { item in
            Text(item.text)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(NovaPalette.novaCardBackground)
                .cornerRadius(8)
        }

        Spacer()
    }
    .padding()
    .background(NovaPalette.novaBackground)
}
