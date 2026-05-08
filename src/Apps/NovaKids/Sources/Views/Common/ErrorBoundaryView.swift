import SwiftUI
import Network

/// App-wide error handling wrapper with graceful error states.
///
/// Generic error, network error, and timeout variants. Provides retry button with exponential backoff.
/// All messaging is kid-friendly and non-technical.
public struct ErrorBoundaryView<Content: View>: View {
    let content: () -> Content
    @State private var error: AppError?
    @State private var retryCount: Int = 0
    @State private var retryTask: Task<Void, Never>?

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        ZStack {
            if let error = error {
                errorView(error)
            } else {
                content()
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AppError"))) { notification in
                        if let appError = notification.object as? AppError {
                            self.error = appError
                        }
                    }
            }
        }
    }

    private func errorView(_ error: AppError) -> some View {
        ZStack {
            NovaPalette.novaBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Icon based on error type
                switch error {
                case .network:
                    ZStack {
                        Circle()
                            .fill(NovaPalette.novaOrange.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "wifi.slash")
                            .font(.largeTitle)
                            .foregroundStyle(NovaPalette.novaOrange)
                    }

                case .timeout:
                    ZStack {
                        Circle()
                            .fill(NovaPalette.novaPurple.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "hourglass")
                            .font(.largeTitle)
                            .foregroundStyle(NovaPalette.novaPurple)
                    }

                case .generic:
                    ZStack {
                        Circle()
                            .fill(NovaPalette.novaPink.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(NovaPalette.novaPink)
                    }
                }

                VStack(spacing: 12) {
                    Text(error.title)
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(.primary)

                    Text(error.message)
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)

                Spacer()

                // Retry button
                Button(action: retryAction) {
                    Text("Try Again")
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    NovaPalette.novaBlue,
                                    NovaPalette.novaPurple
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .accessibilityLabel("Retry button")
            }
        }
    }

    private func retryAction() {
        retryCount += 1
        error = nil

        // Exponential backoff: 1s, 2s, 4s
        let delay = Double(1 << (retryCount - 1))
        retryTask?.cancel()
        retryTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            NotificationCenter.default.post(name: Notification.Name("RetryAppError"), object: nil)
        }
    }
}

// MARK: - Network Status View

/// Persistent banner showing connection state.
public struct NetworkStatusView: View {
    @StateObject private var monitor = NetworkMonitor()

    public var body: some View {
        if !monitor.isConnected {
            HStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .font(.body)
                    .foregroundStyle(.white)

                Text("No connection")
                    .font(NovaPalette.captionFont())
                    .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(NovaPalette.novaOrange)
            .cornerRadius(8)
            .padding(12)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    public init() {}
}

// MARK: - Retryable View

/// Wrapper for views with automatic retry logic.
public struct RetryableView<Content: View>: View {
    let action: () async -> Void
    let content: () -> Content

    @State private var isLoading: Bool = false
    @State private var error: AppError?
    @State private var retryCount: Int = 0

    public init(
        action: @escaping () async -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.action = action
        self.content = content
    }

    public var body: some View {
        ZStack {
            if let error = error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.title2)
                        .foregroundStyle(NovaPalette.novaPink)

                    Text(error.title)
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(.primary)

                    Button(action: attemptRetry) {
                        Text("Try Again")
                            .font(NovaPalette.bodyFont())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(NovaPalette.novaOrange)
                            .cornerRadius(8)
                    }
                    .disabled(isLoading)
                }
                .padding(20)
            } else if isLoading {
                VStack(spacing: 12) {
                    ClassroomSpinner(size: .large, caption: "Loading")

                    Text("Loading...")
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(NovaPalette.classroomInk.opacity(0.78))
                }
            } else {
                content()
            }
        }
        .onAppear(perform: attemptRetry)
    }

    private func attemptRetry() {
        isLoading = true
        error = nil

        Task {
            await action()
            isLoading = false
        }
    }
}

// MARK: - App Error Type

public enum AppError: Error, Identifiable {
    case network(NSError)
    case timeout
    case generic(NSError)

    public var id: String {
        switch self {
        case .network: return "network"
        case .timeout: return "timeout"
        case .generic: return "generic"
        }
    }

    var title: String {
        switch self {
        case .network:
            return "No Internet"
        case .timeout:
            return "Taking Too Long"
        case .generic:
            return "Oops! Something went wrong"
        }
    }

    var message: String {
        switch self {
        case .network:
            return "Check your WiFi and try again"
        case .timeout:
            return "The page is loading slowly. Please try again."
        case .generic:
            return "We're having trouble right now. Please try again."
        }
    }
}

// MARK: - Network Monitor

@MainActor
private class NetworkMonitor: NSObject, ObservableObject {
    @Published var isConnected = true

    private let monitor = NWPathMonitor()

    override init() {
        super.init()
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

#Preview {
    VStack {
        NetworkStatusView()
        Spacer()
        Text("Content here")
        Spacer()
    }
}
