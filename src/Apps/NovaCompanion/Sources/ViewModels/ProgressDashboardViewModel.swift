import Foundation
import NovaCore

/// ViewModel for comprehensive child progress dashboard with analytics.
public class ProgressDashboardViewModel: NSObject, ObservableObject {
    @Published var selectedChildId: String?
    @Published var analytics: ChildAnalytics?
    @Published var isLoading: Bool = false
    @Published var error: String?

    private var apiRouter: APIRouter?

    public override init() {
        super.init()
        loadMockData()
    }

    /// Load analytics for selected child from API
    public func loadAnalytics(childId: String, apiRouter: APIRouter) {
        self.apiRouter = apiRouter
        self.isLoading = true
        self.error = nil

        Task {
            do {
                // In production, this would call the API
                // let analytics = try await apiRouter.fetch(Endpoint.getAnalytics(childId: childId))
                // For now, use mock data
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    /// Refresh analytics (pull-to-refresh)
    public func refreshAnalytics() {
        guard let childId = selectedChildId else { return }
        if let apiRouter = apiRouter {
            loadAnalytics(childId: childId, apiRouter: apiRouter)
        }
    }

    private func loadMockData() {
        selectedChildId = "child-001"

        analytics = ChildAnalytics(
            totalLessons: 24,
            completedLessons: 18,
            completionRate: 75,
            currentStreak: 5,
            longestStreak: 12,
            totalTimeMinutes: 347,
            weeklyHeatmap: [12, 15, 8, 22, 18, 25, 14],
            badgesEarned: 8,
            badgesTotal: 24,
            stageProgress: StageProgress(
                current: "Thinker",
                lessonsToNext: 3
            ),
            recentActivity: [
                ActivityRecord(
                    type: "lesson_completed",
                    title: "Intro to Machine Learning",
                    timestamp: Date().addingTimeInterval(-3600),
                    icon: "checkmark.circle.fill"
                ),
                ActivityRecord(
                    type: "badge_earned",
                    title: "Experiment Master",
                    timestamp: Date().addingTimeInterval(-7200),
                    icon: "star.fill"
                ),
                ActivityRecord(
                    type: "voice_chat",
                    title: "Chatted with AI Assistant",
                    timestamp: Date().addingTimeInterval(-10800),
                    icon: "waveform.circle.fill"
                ),
                ActivityRecord(
                    type: "lesson_completed",
                    title: "Neural Networks Basics",
                    timestamp: Date().addingTimeInterval(-86400),
                    icon: "checkmark.circle.fill"
                ),
                ActivityRecord(
                    type: "experiment_passed",
                    title: "Passed AI Decision Tree Experiment",
                    timestamp: Date().addingTimeInterval(-172800),
                    icon: "checkmark.circle.fill"
                ),
            ]
        )
    }
}

// MARK: - Data Models

/// Child analytics response from backend
public struct ChildAnalytics: Codable {
    public let totalLessons: Int
    public let completedLessons: Int
    public let completionRate: Int // percentage 0-100
    public let currentStreak: Int
    public let longestStreak: Int
    public let totalTimeMinutes: Int
    public let weeklyHeatmap: [Int] // 7 days Mon-Sun
    public let badgesEarned: Int
    public let badgesTotal: Int
    public let stageProgress: StageProgress
    public let recentActivity: [ActivityRecord]

    public init(
        totalLessons: Int,
        completedLessons: Int,
        completionRate: Int,
        currentStreak: Int,
        longestStreak: Int,
        totalTimeMinutes: Int,
        weeklyHeatmap: [Int],
        badgesEarned: Int,
        badgesTotal: Int,
        stageProgress: StageProgress,
        recentActivity: [ActivityRecord]
    ) {
        self.totalLessons = totalLessons
        self.completedLessons = completedLessons
        self.completionRate = completionRate
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.totalTimeMinutes = totalTimeMinutes
        self.weeklyHeatmap = weeklyHeatmap
        self.badgesEarned = badgesEarned
        self.badgesTotal = badgesTotal
        self.stageProgress = stageProgress
        self.recentActivity = recentActivity
    }
}

/// Current stage progress
public struct StageProgress: Codable {
    public let current: String
    public let lessonsToNext: Int

    public init(current: String, lessonsToNext: Int) {
        self.current = current
        self.lessonsToNext = lessonsToNext
    }
}

/// Single activity record
public struct ActivityRecord: Codable, Identifiable {
    public let id: UUID = UUID()
    public let type: String // lesson_completed, badge_earned, experiment_passed, voice_chat
    public let title: String
    public let timestamp: Date
    public let icon: String

    public init(type: String, title: String, timestamp: Date, icon: String) {
        self.type = type
        self.title = title
        self.timestamp = timestamp
        self.icon = icon
    }

    enum CodingKeys: String, CodingKey {
        case type, title, timestamp, icon
    }
}

// MARK: - Preview Mock

#if DEBUG
extension ProgressDashboardViewModel {
    static let preview = ProgressDashboardViewModel()
}
#endif
