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
    @StateObject private var speechSynthesizer: SpeechSynthesizer

    /// S12-12: VoiceManager wraps SpeechSynthesizer (+ optional remote TTS)
    /// and is consumed via @EnvironmentObject by FlipbookView /
    /// StoryCardView / ConceptCardView / VoiceCardView / DashyView. Was
    /// declared in the views but never injected at the app root, causing
    /// `Fatal error: No ObservableObject of type VoiceManager found.` the
    /// first time a kid tapped a voice card. Sharing one
    /// SpeechSynthesizer instance between the @StateObject above and the
    /// VoiceManager below avoids two synthesizers fighting for the same
    /// AVAudioSession.
    @StateObject private var voiceManager: VoiceManager

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
        // S11-19: backend base URL is resolved once through `APIHost.baseURL()`
        // so an iPad on the LAN can point at the Mac's dev server without a
        // recompile. Honors `NOVA_BACKEND_HOST` in the scheme's environment
        // variables, falls back to localhost for simulator runs.
        let backendBaseURL = APIHost.baseURL()

        // Create API client (requires TokenProvider)
        let authManager = AuthManager(
            apiClient: APIClient(
                baseURL: backendBaseURL,
                tokenProvider: AuthManager(
                    apiClient: APIClient(
                        baseURL: backendBaseURL,
                        tokenProvider: _TokenProvider()
                    )
                )
            )
        )

        let apiRouter = APIRouter(
            apiClient: APIClient(
                baseURL: backendBaseURL,
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

        // S12-12: build SpeechSynthesizer + VoiceManager together so they
        // share one instance. VoiceManager.init takes the synth as a
        // constructor param, so we can't rely on the property-default
        // initializer pattern (`= SpeechSynthesizer()`) — both have to
        // be initialized via the StateObject(wrappedValue:) backing-
        // ivar pattern in init.
        let synth = SpeechSynthesizer()
        let voice = VoiceManager(speechSynthesizer: synth)
        _speechSynthesizer = StateObject(wrappedValue: synth)
        _voiceManager = StateObject(wrappedValue: voice)
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
                        .environmentObject(voiceManager)
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

// MARK: - APIHost

/// Resolves the backend base URL at launch.
///
/// ## Why this lives here
///
/// Before S11-19 the `http://localhost:3000/api/v1` string was hard-coded in
/// three places inside `NovaKidsApp.init()` — which is fine for the simulator
/// but fatal for the MVP testing loop bang asked for: iPad on the LAN needs
/// to hit the Mac's dev server, not `localhost` (which on the iPad resolves
/// to the iPad itself).
///
/// ## Resolution order
///
/// 1. `NOVA_BACKEND_HOST` env var, set in the Xcode scheme's "Arguments →
///    Environment Variables" — e.g. `NOVA_BACKEND_HOST=192.168.1.42:3000`.
///    The helper prepends `http://` and appends `/api/v1` so the scheme
///    value stays short and copy-pastable.
/// 2. `http://localhost:3000/api/v1` fallback for simulator + unit tests.
///
/// ## Why an env var, not Info.plist or a build setting
///
/// Env vars flip without a recompile — bang can change Mac IP (Wi-Fi roam,
/// coffee shop, home) and relaunch the iPad target without bumping a build.
/// Info.plist values bake into the bundle; build settings require a rebuild.
enum APIHost {
    static func baseURL() -> URL {
        if let host = ProcessInfo.processInfo.environment["NOVA_BACKEND_HOST"],
           !host.isEmpty,
           let url = URL(string: "http://\(host)/api/v1") {
            return url
        }
        return URL(string: "http://localhost:3000/api/v1")!
    }
}
