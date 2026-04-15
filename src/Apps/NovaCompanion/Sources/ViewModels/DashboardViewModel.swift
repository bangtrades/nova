import Foundation
import NovaCore

/// ViewModel for the Dashboard tab with mock data.
public class DashboardViewModel: ObservableObject {
    @Published var parentName: String = "Alex"
    @Published var quickStats: QuickStats
    @Published var activityFeed: [ActivityFeedItem] = []

    public init() {
        // Mock Quick Stats
        self.quickStats = QuickStats(
            lessonsPublished: 3,
            totalLearningMinutes: 247,
            badgesEarned: 8,
            activeStreak: 5
        )

        // Mock Activity Feed
        self.activityFeed = [
            ActivityFeedItem(
                id: UUID(),
                childName: "Explorer",
                action: "completed",
                lessonTitle: "Intro to Machine Learning",
                timestamp: Date().addingTimeInterval(-3600),
                icon: "checkmark.circle.fill"
            ),
            ActivityFeedItem(
                id: UUID(),
                childName: "Maker",
                action: "earned badge",
                lessonTitle: "Experiment Master",
                timestamp: Date().addingTimeInterval(-7200),
                icon: "star.fill"
            ),
            ActivityFeedItem(
                id: UUID(),
                childName: "Explorer",
                action: "started session",
                lessonTitle: "AI Basics Flipbook",
                timestamp: Date().addingTimeInterval(-10800),
                icon: "play.circle.fill"
            ),
            ActivityFeedItem(
                id: UUID(),
                childName: "Maker",
                action: "completed",
                lessonTitle: "Voice Recognition",
                timestamp: Date().addingTimeInterval(-14400),
                icon: "checkmark.circle.fill"
            ),
            ActivityFeedItem(
                id: UUID(),
                childName: "Explorer",
                action: "earned badge",
                lessonTitle: "Lesson Completionist",
                timestamp: Date().addingTimeInterval(-86400),
                icon: "star.fill"
            ),
        ]
    }
}

public struct QuickStats {
    public let lessonsPublished: Int
    public let totalLearningMinutes: Int
    public let badgesEarned: Int
    public let activeStreak: Int
}

public struct ActivityFeedItem: Identifiable {
    public let id: UUID
    public let childName: String
    public let action: String
    public let lessonTitle: String
    public let timestamp: Date
    public let icon: String
}
