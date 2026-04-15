import Foundation
import NovaCore

/// ViewModel for the trophy room feature.
///
/// Manages badge display, earning tracking, and progress statistics.
@MainActor
public class TrophyRoomViewModel: ObservableObject {
    @Published var badges: [BadgeDisplayItem] = []
    @Published var currentStreak: Int = 0
    @Published var isLoading: Bool = false
    @Published var totalLessonsCompleted: Int = 0

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

    /// Loads badges (in real app, would fetch from API).
    public func loadBadges() async {
        isLoading = true
        defer { isLoading = false }

        // Simulate API call
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Load mock data for now
        loadMockData()
    }

    /// Refreshes badges from server.
    public func refreshBadges() async {
        await loadBadges()
    }

    // MARK: - Private Methods

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
