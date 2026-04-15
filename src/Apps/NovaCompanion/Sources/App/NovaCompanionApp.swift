import SwiftUI
import NovaCore
import NovaAuth
import NovaVoice
import NovaStorage

/// Main entry point for the Nova Companion iPhone/iPad app.
///
/// Provides parent management interface for creating content, managing children,
/// tracking progress, and viewing analytics.
@main
struct NovaCompanionApp: App {
    /// Authentication manager for Sign in with Apple.
    @StateObject private var authManager: AuthManager

    /// API router for backend communication.
    @StateObject private var apiRouter: APIRouter

    /// Sync manager for data synchronization.
    @StateObject private var syncManager: SyncManager

    /// Shared app state.
    @StateObject private var appState: CompanionAppState

    /// Onboarding completion flag.
    @AppStorage("hasCompletedCompanionOnboarding") private var hasCompletedOnboarding = false

    /// Initialize the app with all necessary managers.
    init() {
        let baseURL = URL(string: "https://api.nova.local")!

        // Create AuthManager with temporary token provider
        // AuthManager will become the token provider for APIRouter
        let tempTokenProvider = _AppInitTokenProvider()
        let authManager = AuthManager(
            apiClient: APIClient(
                baseURL: baseURL,
                tokenProvider: tempTokenProvider
            )
        )

        let apiRouter = APIRouter(
            apiClient: APIClient(
                baseURL: baseURL,
                tokenProvider: authManager
            )
        )

        let syncManager = SyncManager(apiRouter: apiRouter)

        let appState = CompanionAppState(
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
            if authManager.isAuthenticated {
                if !hasCompletedOnboarding {
                    // Show onboarding wizard
                    CompanionOnboardingView()
                } else {
                    // Show companion experience for authenticated user
                    CompanionTabView()
                        .environmentObject(authManager)
                        .environmentObject(apiRouter)
                        .environmentObject(syncManager)
                        .environmentObject(appState)
                        .withDeepLinkHandler()
                }
            } else {
                // Show onboarding/login flow
                LoginView()
                    .environmentObject(authManager)
                    .environmentObject(apiRouter)
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, newValue in
            if newValue {
                // Request notification permissions on first authentication
                Task {
                    await NotificationScheduler.shared.requestPermission()
                }
            }
        }
    }

    // MARK: - App Initialization

    /// Creates and initializes all necessary app managers on first launch.
    private func initializeApp() {
        // Perform any initial setup needed for the app
        Task {
            // Load initial data, cache, etc.
        }
    }
}

// MARK: - Main Tab View

/// Main tab navigation for the companion app.
struct CompanionTabView: View {
    @EnvironmentObject var appState: CompanionAppState

    var body: some View {
        TabView {
            // Dashboard Tab
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "gauge")
                }

            // Lessons Tab
            LessonManagerView()
                .tabItem {
                    Label("Lessons", systemImage: "book")
                }

            // Curriculum Tab
            CurriculumView()
                .tabItem {
                    Label("Curriculum", systemImage: "graduationcap")
                }

            // Children Tab
            ChildrenView()
                .tabItem {
                    Label("Children", systemImage: "person.2")
                }

            // Progress Tab
            ProgressTabView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar")
                }

            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

// MARK: - Temporary Token Provider

/// Temporary token provider for app initialization.
/// Replaced by AuthManager once it's created.
private class _AppInitTokenProvider: TokenProvider {
    var accessToken: String? {
        get async { nil }
    }

    var refreshToken: String? {
        get async { nil }
    }

    func updateTokens(accessToken: String, refreshToken: String) async {}

    func clearTokens() async {}
}
