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

    /// S13 — local-first lesson completion tracker. Records "child X
    /// completed lesson Y" tuples to UserDefaults so LessonsView's
    /// checkmark, TrophyRoomView's trophy grid, and the Flipbook's
    /// celebration overlay all read the same source of truth without a
    /// backend round-trip. S14+: shadow-write to backend progress
    /// endpoint for cross-device sync.
    @StateObject private var completionStore = LessonCompletionStore()

    /// S13-07 — Per-child voice persona persistence. UserDefaults JSON
    /// of (childId → voice slug). The kid picks his voice once in
    /// VoicePickerView; every speak() call across StoryCard / ConceptCard
    /// / VoiceCard / DashyView reads from this store via VoiceManager.
    /// resolvedChildId(_:) fallback makes pre-profile sessions work too.
    @StateObject private var voicePreferenceStore = VoicePreferenceStore()

    /// S14-VF-01 — Auto-narrates kid-friendly entry lines on every Tier 1
    /// screen. User Review #01 found the kid couldn't navigate without
    /// adult help because labels (Lessons / Trophies / path titles) are
    /// silent and unreadable to a pre-literate kid. This makes the
    /// navigation chrome speak in his chosen voice via the S13 OpenAI
    /// TTS proxy. Per-screen 60s cooldown + parental mute toggle +
    /// tap-to-skip. Constructed lazily in init() so it can capture the
    /// VoiceManager instance.
    @StateObject private var navigationNarrator: NavigationNarrator

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

        // S13-06: VoiceManager now goes through the backend TTS proxy
        // (`POST /api/v1/voice/tts`) by default — kid hears OpenAI's
        // human-sounding voices instead of robotic AVSpeech. The proxy
        // takes the same Bearer token /lessons takes, so iOS never
        // carries an OPENAI_API_KEY. AVSpeech survives only as the
        // offline fallback.
        //
        // Construction order: synth → tokenResolver (closure capturing
        // authManager) → RemoteTTSClient (with backend baseURL +
        // resolver) → VoiceManager (synth + remote). All three live as
        // long as the App scene.
        let synth = SpeechSynthesizer()
        // Capture authManager weakly through a closure — so token
        // refresh (AuthManager owns its own access-token state) is
        // transparent to RemoteTTSClient on every request.
        let tokenResolver: @Sendable () async -> String? = { [weak authManager] in
            await authManager?.accessToken
        }
        let ttsClient = RemoteTTSClient(
            baseURL: backendBaseURL,
            tokenResolver: tokenResolver
        )
        let voice = VoiceManager(
            speechSynthesizer: synth,
            remoteTTSClient: ttsClient
        )
        _speechSynthesizer = StateObject(wrappedValue: synth)
        _voiceManager = StateObject(wrappedValue: voice)

        // S14-VF-01: NavigationNarrator captures VoiceManager so it can
        // route screen-narration lines through the same OpenAI TTS path
        // every other speak() call uses. Single shared instance — the
        // 60s per-screen cooldown is global state, not per-view.
        let narrator = NavigationNarrator(voiceManager: voice)
        _navigationNarrator = StateObject(wrappedValue: narrator)
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
                        .environmentObject(completionStore)
                        .environmentObject(voicePreferenceStore)
                        .environmentObject(navigationNarrator)
                        // S13-07: hydrate VoiceManager.currentVoice from
                        // the per-child preference. Fires on appear AND on
                        // every change to selected child or stored prefs.
                        // Without this bridge, the kid picks his voice in
                        // settings, the store updates, but VoiceManager
                        // keeps using the launch default.
                        .onAppear {
                            voiceManager.setVoice(
                                voicePreferenceStore.voice(for: appState.currentChild?.id)
                            )
                        }
                        .onChange(of: appState.currentChild?.id) { _, _ in
                            voiceManager.setVoice(
                                voicePreferenceStore.voice(for: appState.currentChild?.id)
                            )
                        }
                        .onChange(of: voicePreferenceStore.records) { _, _ in
                            voiceManager.setVoice(
                                voicePreferenceStore.voice(for: appState.currentChild?.id)
                            )
                        }
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
