import SwiftUI
import Network

/// Offline status banner that slides in/out when connectivity changes.
///
/// Monitors network connectivity via NWPathMonitor and displays a friendly
/// message when the device is offline.
public struct OfflineBannerView: View {
    @State private var isOnline: Bool = true
    @State private var pathMonitor: NWPathMonitor?

    public init() {}

    public var body: some View {
        if !isOnline {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "airplane")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(NovaPalette.novaYellow)

                    Text("You're offline — Sparky will remember your progress!")
                        .font(NovaPalette.smallHeadingFont())
                        .foregroundStyle(.primary)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(height: 44)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            NovaPalette.novaYellow.opacity(0.3),
                            NovaPalette.novaOrange.opacity(0.2)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Private Setup

    private func setupNetworkMonitoring() {
        let monitor = NWPathMonitor()
        self.pathMonitor = monitor

        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                isOnline = path.status == .satisfied
            }
        }

        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
}

#Preview {
    VStack(spacing: 0) {
        OfflineBannerView()

        List {
            ForEach(0..<5, id: \.self) { index in
                Text("Content item \(index + 1)")
            }
        }
    }
}
