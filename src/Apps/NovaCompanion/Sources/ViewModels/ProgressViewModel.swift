import Foundation
import NovaCore

/// ViewModel for progress analytics with mock data.
public class ProgressViewModel: ObservableObject {
    @Published var selectedChildId: UUID?
    @Published var children: [ChildProfile] = []
    @Published var weeklyActivity: [DailyActivity] = []
    @Published var lessonsCompleted: Int = 0
    @Published var averageSessionDuration: Int = 0
    @Published var badgesEarned: [EarnedBadge] = []
    @Published var sessionHistory: [SessionHistoryItem] = []

    public init() {
        loadMockData()
    }

    private func loadMockData() {
        // Mock children
        children = [
            ChildProfile(
                userId: UUID(),
                name: "Explorer",
                birthDate: Calendar.current.date(byAdding: .year, value: -4, to: Date()) ?? Date(),
                currentStage: 1
            ),
            ChildProfile(
                userId: UUID(),
                name: "Maker",
                birthDate: Calendar.current.date(byAdding: .year, value: -7, to: Date()) ?? Date(),
                currentStage: 3
            ),
        ]

        selectedChildId = children.first?.id

        // Mock weekly activity
        var activity: [DailyActivity] = []
        let today = Date()
        for i in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -i, to: today) ?? today
            let minutes = Int.random(in: 5...45)
            activity.append(DailyActivity(date: date, minutesSpent: minutes))
        }
        weeklyActivity = activity.reversed()

        lessonsCompleted = 12
        averageSessionDuration = 18

        // Mock earned badges
        badgesEarned = [
            EarnedBadge(
                childId: children.first?.id ?? UUID(),
                badgeId: UUID(),
                earnedAt: Date().addingTimeInterval(-86400)
            ),
            EarnedBadge(
                childId: children.first?.id ?? UUID(),
                badgeId: UUID(),
                earnedAt: Date().addingTimeInterval(-172800)
            ),
        ]

        // Mock session history
        sessionHistory = [
            SessionHistoryItem(
                date: Date(),
                childName: "Explorer",
                lessonTitle: "What is AI?",
                duration: 22,
                cardsInteracted: 8,
                succeeded: true
            ),
            SessionHistoryItem(
                date: Date().addingTimeInterval(-3600),
                childName: "Maker",
                lessonTitle: "Machine Learning Basics",
                duration: 31,
                cardsInteracted: 12,
                succeeded: true
            ),
            SessionHistoryItem(
                date: Date().addingTimeInterval(-86400),
                childName: "Explorer",
                lessonTitle: "AI in Daily Life",
                duration: 18,
                cardsInteracted: 7,
                succeeded: true
            ),
        ]
    }
}

public struct DailyActivity {
    public let date: Date
    public let minutesSpent: Int
}

public struct SessionHistoryItem: Identifiable {
    public let id = UUID()
    public let date: Date
    public let childName: String
    public let lessonTitle: String
    public let duration: Int
    public let cardsInteracted: Int
    public let succeeded: Bool
}
