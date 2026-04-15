import SwiftUI

/// Graceful offline degradation wrapper.
///
/// Adapts content display based on connectivity and feature availability.
/// Shows feature-appropriate messaging when offline.
public struct OfflineGracefulView<Content: View, OfflineContent: View>: View {
    let isFeatureAvailableOffline: Bool
    let content: () -> Content
    let offlineContent: () -> OfflineContent

    @StateObject private var monitor = OfflineMonitor()

    public init(
        isFeatureAvailableOffline: Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder offlineContent: @escaping () -> OfflineContent
    ) {
        self.isFeatureAvailableOffline = isFeatureAvailableOffline
        self.content = content
        self.offlineContent = offlineContent
    }

    public var body: some View {
        ZStack {
            if monitor.isOnline {
                // Online — show content normally
                content()
            } else if isFeatureAvailableOffline {
                // Offline but available offline — show content with banner
                ZStack(alignment: .top) {
                    content()

                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "wifi.slash")
                                .font(.subheadline)
                                .foregroundStyle(.white)

                            Text("You're offline. Some lessons may not be available.")
                                .font(NovaPalette.captionFont())
                                .foregroundStyle(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(NovaPalette.novaOrange)

                        Spacer()
                    }
                }
            } else {
                // Offline and NOT available offline — show offline content
                offlineContent()
            }
        }
    }
}

// MARK: - Feature-Specific Offline Views

/// Offline view for Sparky voice chat (NOT available offline).
public struct SparkyOfflineView: View {
    public var body: some View {
        ZStack {
            NovaPalette.novaBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(NovaPalette.novaPurple.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "wifi.slash")
                        .font(.largeTitle)
                        .foregroundStyle(NovaPalette.novaPurple)
                }

                VStack(spacing: 12) {
                    Text("Sparky Needs the Internet")
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(.primary)

                    Text("Sparky needs the internet to chat, but you can still explore your lessons!")
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    public init() {}
}

/// Offline view for general content (available offline with cached data).
public struct OfflineAvailableView: View {
    public var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(NovaPalette.novaOrange)

                Text("You're offline")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(NovaPalette.novaOrange.opacity(0.15))
            .cornerRadius(8)
        }
        .padding(16)
    }

    public init() {}
}

// MARK: - Offline Monitor

@MainActor
private class OfflineMonitor: NSObject, ObservableObject {
    @Published var isOnline = true

    private let monitor = NWPathMonitor()

    override init() {
        super.init()
        let queue = DispatchQueue(label: "OfflineMonitor")
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

// MARK: - NWPathMonitor Import

import Network

#Preview {
    OfflineGracefulView(
        isFeatureAvailableOffline: true,
        content: {
            VStack {
                Text("Main Content")
                    .font(NovaPalette.headingFont())
                Spacer()
            }
        },
        offlineContent: {
            SparkyOfflineView()
        }
    )
}
