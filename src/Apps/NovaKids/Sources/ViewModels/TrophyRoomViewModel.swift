import Foundation
import NovaCore

/// ViewModel for the trophy room feature.
///
/// Manages badge display, earning tracking, and progress statistics.
///
/// S11-19: zero-arg `init()` preserved for previews. View attaches router
/// + current childId in its `.task`. When no router is attached the VM
/// falls through to mock data so the trophy grid renders in `#Preview`.
@MainActor
public class TrophyRoomViewModel: ObservableObject {
    @Published var badges: [BadgeDisplayItem] = []
    @Published var currentStreak: Int = 0
    @Published var isLoading: Bool = false
    @Published var totalLessonsCompleted: Int = 0
    @Published var loadError: APIError?

    private var apiRouter: APIRouter?
    /// Without a childId we can still fetch the badge catalog, but we can't
    /// fetch earned-badge records. The VM handles that gracefully: the list
    /// renders with every badge in "unearned" state and zero progress.
    private var childId: UUID?

    /// Displayable badge item with earned status.
    public struct BadgeDisplayItem: Identifiable {
        public var id: UUID { badge.id }
        public let badge: Badge
        public let isEarned: Bool
        public let earnedDate: Date?
        public let progress: Float // 0.0 to 1.0

        public init(
            badge: Badge,
            isEarned: Bool,
            earnedDate: Date? = nil,
            progress: Float = 0
        ) {
            self.badge = badge
            self.isEarned = isEarned
            self.earnedDate = earnedDate
            self.progress = progress
        }
    }

    public init() {
        loadMockData()
    }

    /// Wire the router + current child in from the View's `.task`.
    public func attach(apiRouter: APIRouter, childId: UUID?) {
        self.apiRouter = apiRouter
        self.childId = childId
    }

    /// Loads badges.
    ///
    /// Live path: fetch the badge catalog + earned records in parallel, zip
    /// into `BadgeDisplayItem` rows. Preview / nil-router path falls through
    /// to mock data with a 500ms sleep so the skeleton has a visible-work
    /// beat during pull-to-refresh.
    public func loadBadges() async {
        isLoading = true
        defer { isLoading = false }

        guard let apiRouter else {
            try? await Task.sleep(nanoseconds: 500_000_000)
            loadMockData()
            return
        }

        // Capture @MainActor-isolated state into locals BEFORE the async lets
        // fan out — the `async let` closures may execute off the main actor
        // under Swift 6 strict concurrency, so they can't read instance
        // properties directly. `UUID?` is Sendable so the capture is safe.
        let capturedChildId = childId

        do {
            async let catalogFetch = apiRouter.fetchBadges()
            async let earnedFetch: [EarnedBadge] = {
                if let id = capturedChildId {
                    return try await apiRouter.fetchEarnedBadges(childId: id)
                } else {
                    return []
                }
            }()

            let (catalog, earned) = try await (catalogFetch, earnedFetch)
            let displayCatalog = catalog.isEmpty ? Self.defaultBadgeCatalog : catalog

            // Index earned-by-badge-id so the zip is O(N+M) not O(N*M).
            let earnedByBadgeId: [UUID: EarnedBadge] = Dictionary(
                uniqueKeysWithValues: earned.map { ($0.badgeId, $0) }
            )

            self.badges = displayCatalog.map { badge in
                if let record = earnedByBadgeId[badge.id] {
                    return BadgeDisplayItem(
                        badge: badge,
                        isEarned: true,
                        earnedDate: record.earnedAt,
                        progress: 1.0
                    )
                } else {
                    // Progress for unearned badges is unknown until S12 ships
                    // per-criterion progress endpoints — render 0 for now.
                    return BadgeDisplayItem(
                        badge: badge,
                        isEarned: false,
                        earnedDate: nil,
                        progress: 0
                    )
                }
            }

            // currentStreak + totalLessonsCompleted are not yet surfaced by
            // the API; kept as mock values until S12 ships the progress
            // aggregation endpoint. This is called out in the S11-19 run
            // summary as known follow-up.
            self.currentStreak = 5
            self.totalLessonsCompleted = earned.count
            self.loadError = nil
        } catch let error as APIError {
            if badges.isEmpty {
                loadDefaultBadgeCatalog()
            }
            self.loadError = error
        } catch {
            if badges.isEmpty {
                loadDefaultBadgeCatalog()
            }
            self.loadError = .custom(error.localizedDescription)
        }
    }

    /// Refreshes badges from server.
    public func refreshBadges() async {
        await loadBadges()
    }

    // MARK: - Private Methods

    private static var defaultBadgeCatalog: [Badge] {
        defaultBadgeDefinitions.map { definition in
            Badge(
                id: stableUUID(definition.id),
                title: definition.title,
                description: definition.description,
                icon: definition.icon,
                criteria: definition.criteria
            )
        }
    }

    /// Stable fallback catalog for beta runs where the backend has not
    /// seeded badge definitions yet. Without this, the trophy page can
    /// look like it failed to load even though local lesson trophies
    /// rendered correctly.
    private static let defaultBadgeDefinitions: [(
        id: String,
        title: String,
        description: String,
        icon: String,
        criteria: BadgeCriteria
    )] = [
        (
            "11111111-1111-4111-8111-111111111111",
            "First Lesson",
            "Complete your first lesson",
            "book.circle.fill",
            .init(type: .lessonsCompleted, count: 1)
        ),
        (
            "22222222-2222-4222-8222-222222222222",
            "Lesson Master",
            "Complete 5 lessons",
            "books.vertical.circle.fill",
            .init(type: .lessonsCompleted, count: 5)
        ),
        (
            "33333333-3333-4333-8333-333333333333",
            "Experiment Explorer",
            "Complete 3 experiments",
            "flask.fill",
            .init(type: .experimentsCompleted, count: 3)
        ),
        (
            "44444444-4444-4444-8444-444444444444",
            "Quiz Whiz",
            "Answer 10 quiz questions correctly",
            "questionmark.circle.fill",
            .init(type: .lessonsCompleted, count: 10)
        ),
        (
            "55555555-5555-4555-8555-555555555555",
            "Voice Adventurer",
            "Record 5 voice responses",
            "mic.circle.fill",
            .init(type: .voiceInteractions, count: 5)
        ),
        (
            "66666666-6666-4666-8666-666666666666",
            "3-Day Streak",
            "Learn for 3 days in a row",
            "flame.circle.fill",
            .init(type: .daysStreak, count: 3)
        ),
        (
            "77777777-7777-4777-8777-777777777777",
            "AI Genius",
            "Complete the AI Basics path",
            "sparkles",
            .init(type: .pathCompleted, count: 1)
        ),
        (
            "88888888-8888-4888-8888-888888888888",
            "Week Warrior",
            "Learn for 7 days straight",
            "calendar.circle.fill",
            .init(type: .daysStreak, count: 7)
        ),
    ]

    private static func stableUUID(_ rawValue: String) -> UUID {
        UUID(uuidString: rawValue) ?? UUID()
    }

    private func loadDefaultBadgeCatalog() {
        badges = Self.defaultBadgeCatalog.map { badge in
            BadgeDisplayItem(
                badge: badge,
                isEarned: false,
                earnedDate: nil,
                progress: 0
            )
        }
        currentStreak = 0
        totalLessonsCompleted = 0
    }

    private func loadMockData() {
        // Create mock badges
        let badgeDefinitions: [(title: String, description: String, icon: String, criteria: BadgeCriteria, isEarned: Bool, earnedDate: Date?)] = [
            ("First Lesson", "Complete your first lesson", "book.circle.fill", .init(type: .lessonsCompleted, count: 1), true, Date().addingTimeInterval(-86400 * 7)),
            ("Lesson Master", "Complete 5 lessons", "books.vertical.circle.fill", .init(type: .lessonsCompleted, count: 5), true, Date().addingTimeInterval(-86400 * 3)),
            ("Experiment Explorer", "Complete 3 experiments", "flask.fill", .init(type: .experimentsCompleted, count: 3), true, Date().addingTimeInterval(-86400 * 2)),
            ("Quiz Whiz", "Answer 10 quiz questions correctly", "questionmark.circle.fill", .init(type: .lessonsCompleted, count: 10), true, Date().addingTimeInterval(-86400)),
            ("Voice Adventurer", "Record 5 voice responses", "mic.circle.fill", .init(type: .voiceInteractions, count: 5), false, nil),
            ("3-Day Streak", "Learn for 3 days in a row", "flame.circle.fill", .init(type: .daysStreak, count: 3), true, Date().addingTimeInterval(-86400 * 4)),
            ("AI Genius", "Complete the AI Basics path", "sparkles", .init(type: .pathCompleted, count: 1), false, nil),
            ("Week Warrior", "Learn for 7 days straight", "calendar.circle.fill", .init(type: .daysStreak, count: 7), false, nil),
        ]

        badges = badgeDefinitions.map { def in
            let criteria = def.criteria
            let estimatedProgress: Float = def.isEarned ? 1.0 : Float.random(in: 0.3...0.8)

            return BadgeDisplayItem(
                badge: Badge(
                    id: UUID(),
                    title: def.title,
                    description: def.description,
                    icon: def.icon,
                    criteria: criteria
                ),
                isEarned: def.isEarned,
                earnedDate: def.earnedDate,
                progress: estimatedProgress
            )
        }

        currentStreak = 5
        totalLessonsCompleted = 8
    }
}
