import Foundation
import Combine

/// S13-07 — Per-child persistent record of which voice persona a kid has
/// chosen. Mirrors the `LessonCompletionStore` pattern exactly: UserDefaults-
/// backed JSON, MainActor-isolated, @Published reactive surface, single
/// `resolvedChildId(_:)` resolution helper to keep writes and reads agreeing.
///
/// **Why this exists separately from VoiceManager:** VoiceManager holds the
/// *currently active* voice (single value, in-memory, swapped per `speak()`).
/// VoicePreferenceStore holds *every kid's preference across launches* (a
/// dictionary, persistent). The picker writes to the store; the store
/// publishes the change; views observing the store re-render. VoiceManager
/// reads through the store at lesson-load time to pick up the kid's choice.
///
/// **Why per-child not global:** the demo iPad will eventually hold two
/// siblings' profiles. Each kid wants his own voice. Tying the preference to
/// `childId` (with a stable per-device fallback when no profile is selected)
/// means a sibling switch flips voices automatically.
///
/// **Persistence:** UserDefaults under `voicePreference.records.v1`. JSON-
/// encoded `[VoicePreferenceRecord]`. S14+ shadow-write to backend via
/// `/children/:id/preferences` so cross-device install carries the choice.
@MainActor
public final class VoicePreferenceStore: ObservableObject {
    /// One row per (childId → voice slug). UUIDs as Strings for JSON-friendly
    /// UserDefaults persistence; voice is the OpenAI slug (`nova` / `fable`
    /// / `onyx` / `shimmer`).
    public struct VoicePreferenceRecord: Codable, Identifiable, Equatable, Sendable {
        public let id: String           // childId UUID string — the row key
        public let voice: String        // OpenAI voice slug
        public let updatedAt: Date

        public init(id: String, voice: String, updatedAt: Date = Date()) {
            self.id = id
            self.voice = voice
            self.updatedAt = updatedAt
        }
    }

    /// Reactive list of all per-child voice preferences. Most recent first.
    @Published public private(set) var records: [VoicePreferenceRecord] = []

    /// Default voice slug for any child who has not yet picked. `nova` is the
    /// most kid-friendly stock voice (bright, energetic, age-appropriate cadence).
    public static let defaultVoice = "nova"

    /// Allowed voice slugs — mirrors the backend `/voice/voices` payload.
    /// Kept here rather than imported from RemoteTTSClient so that this
    /// store has no NovaVoice import cycle.
    public static let allowedVoices: Set<String> = ["nova", "fable", "onyx", "shimmer"]

    private let defaults: UserDefaults
    private let storageKey = "voicePreference.records.v1"
    private let fallbackChildIdKey = "voicePreference.fallbackChildId"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.records = loadFromDefaults()
    }

    // MARK: - Resolved child id
    //
    // Same idiom LessonCompletionStore uses. If the kid hasn't selected a
    // profile yet, every read AND write goes through a stable per-device
    // UUID kept in UserDefaults. Without this, a preference written with
    // `nil` childId never matches the read with the same `nil` childId
    // because the lookup short-circuits.

    /// Returns a non-nil child id. If `childId` is provided, returns it
    /// as-is; otherwise returns a stable per-device UUID kept in
    /// UserDefaults (created on first call, reused thereafter).
    public func resolvedChildId(_ childId: UUID?) -> UUID {
        if let childId { return childId }
        if let stored = defaults.string(forKey: fallbackChildIdKey),
           let uuid = UUID(uuidString: stored) {
            return uuid
        }
        let new = UUID()
        defaults.set(new.uuidString, forKey: fallbackChildIdKey)
        return new
    }

    // MARK: - Public API

    /// Record (or update) a kid's voice preference. Idempotent — if a
    /// record exists for this child, replaces it; otherwise inserts.
    /// Validates `voice` against the allow-list and silently no-ops on
    /// invalid input rather than corrupting persisted state.
    public func setVoice(_ voice: String, for childId: UUID?) {
        guard Self.allowedVoices.contains(voice) else { return }
        let resolved = resolvedChildId(childId)
        let id = resolved.uuidString

        let record = VoicePreferenceRecord(id: id, voice: voice, updatedAt: Date())
        var next = records.filter { $0.id != id }
        next.insert(record, at: 0)
        records = next
        persist()
    }

    /// Get the kid's preferred voice. Falls back to `defaultVoice` (`nova`)
    /// when the kid hasn't picked yet — never returns nil so call sites
    /// can use the result directly without unwrapping.
    public func voice(for childId: UUID?) -> String {
        let resolved = resolvedChildId(childId)
        let id = resolved.uuidString
        return records.first(where: { $0.id == id })?.voice ?? Self.defaultVoice
    }

    /// Has this child explicitly picked a voice (vs. just defaulting)?
    /// Onboarding uses this to decide whether to nudge them through the
    /// picker on first launch.
    public func hasChosen(childId: UUID?) -> Bool {
        let resolved = resolvedChildId(childId)
        let id = resolved.uuidString
        return records.contains(where: { $0.id == id })
    }

    /// Clear a single kid's preference (debug + parental-reset path).
    public func clear(for childId: UUID?) {
        let resolved = resolvedChildId(childId)
        let id = resolved.uuidString
        records = records.filter { $0.id != id }
        persist()
    }

    /// Drop every preference. Debug-only path; surfaces in Oracle as
    /// "reset all voice preferences" once the Voice tab lands.
    public func clearAll() {
        records = []
        persist()
    }

    // MARK: - Persistence

    private func loadFromDefaults() -> [VoicePreferenceRecord] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([VoicePreferenceRecord].self, from: data)
        } catch {
            // Corrupt/incompatible — start fresh rather than crash. A v0→v1
            // schema bump would land here; losing voice prefs is way better
            // than locking the kid out of the app.
            print("[VoicePreferenceStore] Failed to decode records: \(error). Starting fresh.")
            return []
        }
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(records)
            defaults.set(data, forKey: storageKey)
        } catch {
            print("[VoicePreferenceStore] Failed to persist records: \(error)")
        }
    }
}
