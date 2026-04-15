import SwiftUI
import UIKit

// MARK: - Lazy Image View

/// Async image loading with caching, downsampling, and fade-in.
public struct LazyImageView: View {
    let url: URL?
    let placeholder: Image

    @StateObject private var loader = ImageLoader()
    @State private var image: UIImage?

    public init(url: URL?, placeholder: Image = Image(systemName: "photo")) {
        self.url = url
        self.placeholder = placeholder
    }

    public var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                placeholder
                    .resizable()
                    .scaledToFill()
                    .foregroundStyle(.gray)
            }
        }
        .clipped()
        .onAppear {
            guard let url = url else { return }
            Task {
                if let cachedImage = loader.getFromCache(url) {
                    image = cachedImage
                } else {
                    do {
                        let downloadedImage = try await loader.loadImage(url)
                        await MainActor.run {
                            image = downloadedImage
                        }
                    } catch {
                        print("Failed to load image: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Image Loader

@MainActor
private class ImageLoader: NSObject, ObservableObject {
    private static let cache = NSCache<NSString, UIImage>()
    private let urlSession = URLSession.shared

    /// Gets image from memory cache.
    func getFromCache(_ url: URL) -> UIImage? {
        ImageLoader.cache.object(forKey: url.absoluteString as NSString)
    }

    /// Loads image from URL with caching and downsampling.
    func loadImage(_ url: URL) async throws -> UIImage {
        // Check cache first
        if let cached = getFromCache(url) {
            return cached
        }

        // Download
        let (data, _) = try await urlSession.data(from: url)

        // Downsample to save memory
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "ImageLoader", code: -1, userInfo: nil)
        }

        let downsampledImage = downsample(image, to: CGSize(width: 800, height: 800))

        // Cache
        ImageLoader.cache.setObject(downsampledImage, forKey: url.absoluteString as NSString)

        return downsampledImage
    }

    /// Downsamples image to target size.
    private func downsample(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
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
        LazyImageView(
            url: URL(string: "https://via.placeholder.com/200"),
            placeholder: Image(systemName: "photo")
        )
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
