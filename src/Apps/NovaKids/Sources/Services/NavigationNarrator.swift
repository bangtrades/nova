import Foundation
import SwiftUI
import NovaVoice

/// S14-VF-01 — Auto-narrates kid-friendly entry lines on every Tier 1
/// screen.
///
/// **Why this exists:** User Review #01 found that a 4.5-year-old can't
/// navigate Novai because the navigation chrome is silent — labels like
/// "Lessons" / "Trophies" / path titles are unreadable to a pre-literate
/// kid. The S13 voice upgrade made the *content* speak (every card
/// narrates via OpenAI TTS); S14 makes the *navigation* speak too. Half
/// the app speaking, half silent, is worse than fully silent — kids
/// learn the audio is intermittent and stop relying on it.
///
/// **What it does:** A view modifier `.narrate(_:)` placed on any view
/// fires a per-screen narration line on `onAppear`, routed through the
/// existing `VoiceManager` (S13 OpenAI TTS proxy in the kid's chosen
/// voice persona). The line is:
///   - Pulled from a per-screen registry (NavigationScript.line(for:))
///   - Skipped if the screen was narrated within the cooldown window
///     (default 60s — re-navigating back doesn't re-narrate)
///   - Skipped if the parental mute toggle is on
///   - Cancellable via `cancelCurrentNarration()` (e.g., on tap-anywhere)
///
/// **Why @MainActor:** mutates `currentScreen` + `lastNarratedAt` from
/// view-driven contexts; AVAudioPlayer playback also wants main actor.
///
/// **Why one shared instance:** the cooldown bookkeeping is global —
/// every Tier 1 surface shares a single timeline. Per-view local state
/// would re-narrate on every back-nav.
@MainActor
public final class NavigationNarrator: ObservableObject {
    /// Whether parental mute is on. Persisted to UserDefaults so the
    /// kid-side behaviour survives launches. Default `false` (narration
    /// on) — User Review #01 explicitly flagged silence as the breaking
    /// failure mode. Adults disable via Settings.
    @Published public var isMuted: Bool {
        didSet { defaults.set(isMuted, forKey: muteKey) }
    }

    /// Whether a narration is currently playing. Drives the "tap to
    /// skip" pill visibility on the parent view.
    @Published public private(set) var isNarrating: Bool = false

    /// Most recent screen that requested narration. Useful for debug +
    /// for re-narrating on demand (kid taps Dashy → repeat last line).
    @Published public private(set) var currentScreen: String? = nil

    /// Per-screen "last narrated at" timeline. Keyed by screen id;
    /// values are absolute timestamps. Kept in memory (no persistence)
    /// — cooldown is per-app-session by design.
    private var lastNarratedAt: [String: Date] = [:]

    /// Cooldown window — within this many seconds of the last narration
    /// of the same screen, re-narration is suppressed. 60s lets a kid
    /// pop back to Home from Lessons without hearing the home line a
    /// second time, but if he genuinely revisits after a minute (e.g.
    /// finishes a lesson then explores again) the line plays again.
    public var cooldownSeconds: TimeInterval = 60

    /// Voice manager — speaks the line in the kid's chosen voice.
    /// Optional (test path) but production always passes a real one.
    private let voiceManager: VoiceManager?

    /// Active narration task. Held so we can cancel mid-playback when
    /// the kid taps to skip or navigates away.
    private var activeTask: Task<Void, Never>? = nil

    private let defaults: UserDefaults
    private let muteKey = "navigationNarrator.muted.v1"

    public init(
        voiceManager: VoiceManager?,
        defaults: UserDefaults = .standard
    ) {
        self.voiceManager = voiceManager
        self.defaults = defaults
        self.isMuted = defaults.bool(forKey: muteKey)
    }

    /// Trigger narration for the given screen. Idempotent within
    /// `cooldownSeconds`. No-op if muted. Caller is the
    /// `.narrate(_:)` view modifier — direct calls are also fine
    /// (e.g., kid taps Dashy → call `narrate("home", force: true)`).
    ///
    /// - Parameters:
    ///   - screen: Stable identifier for the surface. Drives both the
    ///     cooldown lookup and the script-registry lookup.
    ///   - script: Optional inline override. When `nil`,
    ///     `NavigationScript.line(for:)` resolves the line.
    ///   - force: Bypass cooldown. Used when the kid explicitly
    ///     requests re-narration (tap Dashy).
    public func narrate(
        _ screen: String,
        script: String? = nil,
        force: Bool = false
    ) {
        guard !isMuted else { return }

        // Cooldown check — same screen within window, skip.
        if !force,
           let last = lastNarratedAt[screen],
           Date().timeIntervalSince(last) < cooldownSeconds {
            return
        }

        // Resolve the line. If neither inline nor registry has a line
        // for this screen, no-op silently — it's better to be quiet on
        // an unknown surface than to speak a generic placeholder a kid
        // would learn to ignore.
        guard let line = script ?? NavigationScript.line(for: screen) else { return }

        // Cancel any in-flight narration so the new screen takes over.
        cancelCurrentNarration()

        currentScreen = screen
        isNarrating = true
        lastNarratedAt[screen] = Date()

        activeTask = Task { [weak self] in
            guard let voice = self?.voiceManager else {
                self?.isNarrating = false
                return
            }
            do {
                try await voice.speak(text: line)
            } catch {
                // Silent failure on narration — better than crashing
                // the kid's flow over a TTS hiccup. VoiceManager
                // already falls back to AVSpeech on remote failure.
                print("[NavigationNarrator] narrate(\(screen)) failed: \(error.localizedDescription)")
            }
            await MainActor.run {
                self?.isNarrating = false
            }
        }
    }

    /// Cancel any active narration immediately. Used by tap-to-skip
    /// + by re-narration triggers that need to override the current
    /// playback.
    public func cancelCurrentNarration() {
        activeTask?.cancel()
        activeTask = nil
        voiceManager?.stop()
        isNarrating = false
    }

    /// Reset the cooldown timeline — typically only needed for tests
    /// or for a "demo mode" debug toggle in Oracle.
    public func resetCooldowns() {
        lastNarratedAt.removeAll()
    }
}

/// Per-screen narration script registry.
///
/// Scripts are kept here (a) so they can be edited without rebuilding
/// the views that consume them and (b) so they can eventually be
/// localized and (c) so a future S15+ "narration script preview"
/// affordance in Oracle can dry-run them before they ship.
///
/// Scripts are intentionally short (≤ 14 words) — kids tune out long
/// instructions. Tone is conversational and uses contractions ("Let's,"
/// "I'm") because OpenAI TTS handles them naturally and they sound
/// human.
public enum NavigationScript {
    /// Resolve the narration line for the given screen identifier.
    /// Returns nil if no line is registered for that screen — the
    /// narrator silently skips rather than playing a generic
    /// placeholder.
    public static func line(for screen: String) -> String? {
        switch screen {
        case "home":
            return "Hi! I'm Dashy. Pick a topic to start learning. Tap any card you see!"
        case "lessons":
            return "These are the lessons. Tap one to start!"
        case "classroomBookshelf":
            return "Pick a lesson book from the shelf."
        case "classroomBookshelfEmpty":
            return "Looks like the bookshelf is empty! Ask a grown-up to add a lesson book."
        case "lessonDetail":
            return "Let's begin! Tap the arrow to see the first card."
        case "trophyRoom":
            return "Look at all your trophies! Tap one to remember what you learned."
        case "voicePicker":
            return "Pick a friend to read your stories. Tap any of them to hear what they sound like!"
        case "parentalGate":
            return "This part is for grown-ups."
        case "homeEmpty":
            return "Looks like there's nothing here yet. Ask a grown-up to add a lesson!"
        case "lessonsEmpty":
            return "No lessons here yet! Ask a grown-up to add some."
        case "trophyRoomEmpty":
            return "No trophies yet! Finish a lesson to earn your first one."
        default:
            return nil
        }
    }

    /// Dynamic-script variants — caller supplies the data, registry
    /// builds a kid-friendly sentence around it. Used for screens
    /// where the line depends on context (e.g., the path's name).
    public static func lessonsLine(forPathName name: String?) -> String {
        guard let name, !name.isEmpty else { return line(for: "lessons") ?? "" }
        return "These are the \(name) lessons. Tap one to start!"
    }

    /// Greet by name when known. Falls back to the default home line.
    public static func homeLine(forKidName name: String?) -> String {
        guard let name, !name.isEmpty else { return line(for: "home") ?? "" }
        return "Hi \(name)! I'm Dashy. Pick a topic to start learning!"
    }
}

// MARK: - View modifier

extension View {
    /// Trigger narration for the given screen identifier on appear.
    ///
    /// Usage:
    /// ```swift
    /// HomeView()
    ///     .narrate("home")
    /// ```
    ///
    /// For dynamic scripts (where the line depends on runtime data):
    /// ```swift
    /// LessonsView()
    ///     .narrate("lessons", script: NavigationScript.lessonsLine(forPathName: path.name))
    /// ```
    public func narrate(
        _ screen: String,
        script: String? = nil
    ) -> some View {
        modifier(NarrateModifier(screen: screen, script: script))
    }
}

private struct NarrateModifier: ViewModifier {
    let screen: String
    let script: String?

    @EnvironmentObject private var narrator: NavigationNarrator

    func body(content: Content) -> some View {
        content.onAppear {
            narrator.narrate(screen, script: script)
        }
    }
}
