import SwiftUI
import NovaCore
import NovaAuth
import NovaVoice
import NovaStorage
import BackgroundTasks

/// Main entry point for the Nova Kids iPad app.
///
/// Initializes all managers and provides root view switching based on authentication state.
/// iPad-only app optimized for children aged 4-10.
@main
struct NovaKidsApp: App {
    /// Authentication manager for Sign in with Apple.
    @StateObject private var authManager: AuthManager

    /// API router for backend communication.
    @StateObject private var apiRouter: APIRouter

    /// Sync manager for coordinating data synchronization.
    @StateObject private var syncManager: SyncManager

    /// Shared app state.
    @StateObject private var appState: KidsAppState

    /// Speech synthesizer for voice narration.
    @StateObject private var speechSynthesizer = SpeechSynthesizer()

    /// Asset cache manager for preloading lessons.
    @StateObject private var assetCacheManager = AssetCacheManager()

    /// Background task manager for offline sync and asset preload.
    @StateObject private var backgroundTaskManager = BackgroundTaskManager()

    /// Memory warning handler for cache management.
    @StateObject private var memoryHandler = MemoryWarningHandler()

    /// App storage flags for onboarding and age gate.
    @AppStorage("hasPassedAgeGate") var hasPassedAgeGate = false
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false

    /// Initialize the app with all necessary managers.
    init() {
        // Create API client (requires TokenProvider)
        let authManager = AuthManager(
            apiClient: APIClient(
                baseURL: URL(string: "http://localhost:3000/api/v1")!,
                tokenProvider: AuthManager(
                    apiClient: APIClient(
                        baseURL: URL(string: "http://localhost:3000/api/v1")!,
                        tokenProvider: _TokenProvider()
                    )
                )
            )
        )

        let apiRouter = APIRouter(
            apiClient: APIClient(
                baseURL: URL(string: "http://localhost:3000/api/v1")!,
                tokenProvider: authManager
            )
        )

        let syncManager = SyncManager(apiRouter: apiRouter)

        let appState = KidsAppState(
            authManager: authManager,
            apiRouter: apiRouter,
            syncManager: syncManager
        )

        _authManager = StateObject(wrappedValue: authManager)
        _apiRouter = StateObject(wrappedValue: apiRouter)
        _syncManager = StateObject(wrappedValue: syncManager)
        _appState = StateObject(wrappedValue: appState)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !hasPassedAgeGate {
                    // Age gate first
                    AgeGateView()
                } else if !hasCompletedOnboarding {
                    // Then onboarding
                    OnboardingView()
                } else if authManager.isAuthenticated {
                    // Show learning experience for authenticated user
                    TabBarView()
                        .environmentObject(authManager)
                        .environmentObject(apiRouter)
                        .environmentObject(syncManager)
                        .environmentObject(appState)
                        .environmentObject(speechSynthesizer)
                        .environmentObject(assetCacheManager)
                } else {
                    // Show login flow
                    #if DEBUG
                    // Dev bypass — skip Apple Sign In for testing
                    VStack(spacing: 24) {
                        KidsLoginView()
                            .environmentObject(authManager)
                            .environmentObject(apiRouter)

                        Button(action: {
                            // Skip auth for development testing
                            Task {
                                await authManager.devBypassLogin()
                            }
                        }) {
                            Text("⚡ Dev: Skip Login")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.8))
                                .clipShape(Capsule())
                        }
                        .padding(.bottom, 20)
                    }
                    #else
                    KidsLoginView()
                        .environmentObject(authManager)
                        .environmentObject(apiRouter)
                    #endif
                }

                // Network status banner (overlay)
                VStack {
                    NetworkStatusView()
                    Spacer()
                }
            }
            .fontDesign(.rounded)
            .preferredColorScheme(nil) // Respect system light/dark mode
            .onAppear {
                // Setup background task handlers
                backgroundTaskManager.setupBackgroundTasks(
                    syncManager: syncManager,
                    assetCacheManager: assetCacheManager
                )
            }
        }
    }
}

// MARK: - Tab Bar Navigation

/// Main tab bar view with 4 primary tabs.
struct TabBarView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // Home tab
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                // Lessons tab
                LessonsView()
                    .tabItem {
                        Label("Lessons", systemImage: "books.vertical.fill")
                    }
                    .tag(1)

                // Dashy tab
                DashyView()
                    .tabItem {
                        Label("Dashy", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                    .tag(2)

                // Trophies tab
                TrophyRoomView()
                    .tabItem {
                        Label("Trophies", systemImage: "trophy.fill")
                    }
                    .tag(3)
            }
            .tint(NovaPalette.novaOrange)
        }
    }
}


// MARK: - Temporary Token Provider

/// Temporary token provider for initialization (actual impl in AuthManager).
private class _TokenProvider: TokenProvider {
    var accessToken: String? {
        get async { nil }
    }

    var refreshToken: String? {
        get async { nil }
    }

    func updateTokens(accessToken: String, refreshToken: String) async {}

    func clearTokens() async {}
}
