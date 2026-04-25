import Foundation
import Combine

/// S13 — Per-child persistent record of which lessons have been completed.
///
/// Every time a kid hits "Finish" on the last card of a lesson, we record
/// `(childId, lessonId, completedAt)` here so:
///   - LessonsView can render a checkmark badge on completed tiles
///   - TrophyRoomView can show a "Your Trophies" section with one trophy
///     card per completed lesson, using the lesson's hero image as the
///     trophy art
///   - The celebration overlay knows whether this is a first-time
///     completion (full confetti + "You earned X!") or a re-play (smaller
///     "Welcome back to X!" reaction)
///
/// Persistence: `UserDefaults` keyed under `LessonCompletion.<childId>`.
/// JSON-encoded array of TrophyRecord. Lightweight, instant, no backend
/// round-trip required for the kid demo. S14+ should sync this to the
/// backend's progress endpoint so completions survive device wipes.
///
/// Concurrency: `@MainActor` — every mutation re-publishes `records` so
/// every Tier-1 view that depends on completion state (LessonsView,
/// TrophyRoomView, HomeView's continue-learning) stays in sync without
/// per-view fetches.
@MainActor
public final class LessonCompletionStore: ObservableObject {
    /// One trophy = one (child, lesson) pair. UUIDs are stored as strings
    /// for JSON-encoded UserDefaults persistence; `lessonHeroImageURL` is
    /// captured at completion time so the Trophy room can keep showing
    /// the panel image even if the lesson is later deleted from the DB.
    public struct TrophyRecord: Codable, Identifiable, Equatable {
        public let id: String          // composite "<childId>:<lessonId>" for SwiftUI ForEach
        public let childId: String
        public let lessonId: String
        public let lessonTitle: String
        public let lessonHeroImageURL: String?
        public let completedAt: Date

        /// Trophy display name — derived from the lesson title.
        /// "Sky - Simple English Wikipedia" → "Sky Champion".
        public var trophyName: String {
            let cleanTitle = lessonTitle
                .replacingOccurrences(of: " - Simple English Wikipedia, the free encyclopedia", with: "")
                .replacingOccurrences(of: " - Wikipedia", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(cleanTitle) Champion"
        }
    }

    /// Reactive list of all trophies earned across all kids on this device.
    @Published public private(set) var records: [TrophyRecord] = []

    private let defaults: UserDefaults
    private let storageKey = "lessonCompletion.records.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.records = loadFromDefaults()
    }

    // MARK: - Public API

    /// Record a lesson completion. Idempotent — re-completing an already
    /// completed lesson updates `completedAt` and bumps it to the front
    /// of the list (so "most recent trophy" surfaces first), but doesn't
    /// duplicate. Returns true if this is the first time this child
    /// completed this lesson — the celebration view uses this to decide
    /// between full-confetti first-time and a softer welcome-back beat.
    @discardableResult
    public func recordCompletion(
        childId: UUID,
        lessonId: UUID,
        lessonTitle: String,
        lessonHeroImageURL: URL?
    ) -> Bool {
        let composite = "\(childId.uuidString):\(lessonId.uuidString)"
        let isFirstTime = !records.contains(where: { $0.id == composite })

        let trophy = TrophyRecord(
            id: composite,
            childId: childId.uuidString,
            lessonId: lessonId.uuidString,
            lessonTitle: lessonTitle,
            lessonHeroImageURL: lessonHeroImageURL?.absoluteString,
            completedAt: Date()
        )

        // Drop any existing record with the same composite id, then prepend.
        var next = records.filter { $0.id != composite }
        next.insert(trophy, at: 0)
        records = next
        persist()
        return isFirstTime
    }

    /// Has the given child completed the given lesson?
    public func hasCompleted(childId: UUID?, lessonId: UUID) -> Bool {
        guard let childId else { return false }
        let composite = "\(childId.uuidString):\(lessonId.uuidString)"
        return records.contains(where: { $0.id == composite })
    }

    /// Trophies for a specific child, newest-first.
    public func trophies(for childId: UUID?) -> [TrophyRecord] {
        guard let childId else { return [] }
        let target = childId.uuidString
        return records.filter { $0.childId == target }
    }

    /// Total trophies count for a child — used by Home's tile.
    public func trophyCount(for childId: UUID?) -> Int {
        trophies(for: childId).count
    }

    // MARK: - Persistence

    private func loadFromDefaults() -> [TrophyRecord] {
        guard let data = defaults.data(forKey: storageKey) else { return [] }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([TrophyRecord].self, from: data)
        } catch {
            // Corrupt/incompatible stored data — start fresh rather than crash.
            // Touch-test reality: a v0 → v1 schema change would land here, and
            // losing trophies is way better than locking the kid out of the app.
            print("[LessonCompletionStore] Failed to decode records: \(error). Starting fresh.")
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
            print("[LessonCompletionStore] Failed to persist records: \(error)")
        }
    }
}
