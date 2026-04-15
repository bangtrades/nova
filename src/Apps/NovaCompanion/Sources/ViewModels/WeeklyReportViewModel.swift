import Foundation
import SwiftUI
import NovaCore

/// View model for weekly report with analytics and sharing.
public class WeeklyReportViewModel: ObservableObject {
    @Published var selectedChildId: String?
    @Published var report: WeeklyReport?
    @Published var isLoading: Bool = false
    private var loadTask: Task<Void, Never>?

    public init() {}

    /// Load weekly report data from analytics.
    public func loadReport() {
        isLoading = true

        // Simulate network delay
        loadTask?.cancel()
        loadTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            let today = Date()
            let calendar = Calendar.current
            let sunday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!

            self.report = WeeklyReport(
                dateRange: dateRangeString(from: sunday, to: today),
                childName: "Alex",
                lessonsCompleted: 5,
                totalMinutes: 245,
                newBadges: 2,
                currentStreak: 7,
                highlight: "Alex completed 5 lessons this week and earned the 'Curious Mind' badge!",
                weeklyBreakdown: [
                    ActivityBreakdown(
                        activityType: "Lessons",
                        minutes: 180,
                        percentage: 73.5,
                        color: CompanionPalette.novaBlue
                    ),
                    ActivityBreakdown(
                        activityType: "Experiments",
                        minutes: 45,
                        percentage: 18.4,
                        color: CompanionPalette.novaGreen
                    ),
                    ActivityBreakdown(
                        activityType: "Quizzes",
                        minutes: 20,
                        percentage: 8.1,
                        color: CompanionPalette.novaYellow
                    ),
                ],
                vsLastWeek: ComparisonMetrics(
                    lessonsChange: "+3",
                    lessonsPercentage: 150,
                    timeChange: "+95 min",
                    timePercentage: 63,
                    badgesChange: "+1",
                    badgesPercentage: 100
                ),
                recommendations: [
                    "Alex is doing great! Keep encouraging daily practice to maintain the 7-day streak.",
                    "Try exploring more experiments — Alex loves hands-on activities.",
                    "Consider introducing voice chat exercises for speaking practice.",
                ]
            )

            self.isLoading = false
        }
    }

    deinit {
        loadTask?.cancel()
    }

    /// Formatted text for sharing report.
    public var shareText: String {
        guard let report = report else { return "" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"

        return """
        🎉 Nova Weekly Report

        Week of \(report.dateRange)

        📊 Summary for \(report.childName):
        • Lessons Completed: \(report.lessonsCompleted)
        • Learning Time: \(report.totalMinutes) minutes
        • New Badges: \(report.newBadges)
        • Active Streak: \(report.currentStreak) days

        ✨ This Week's Achievement:
        \(report.highlight)

        📈 Comparison to Last Week:
        • Lessons: \(report.vsLastWeek.lessonsChange) (\(String(format: "%.0f%%", report.vsLastWeek.lessonsPercentage)) change)
        • Learning Time: \(report.vsLastWeek.timeChange) (\(String(format: "%.0f%%", report.vsLastWeek.timePercentage)) change)
        • Badges: \(report.vsLastWeek.badgesChange) (\(String(format: "%.0f%%", report.vsLastWeek.badgesPercentage)) change)

        Created with Nova Companion
        """
    }
}

// MARK: - Models

public struct WeeklyReport {
    public let dateRange: String
    public let childName: String
    public let lessonsCompleted: Int
    public let totalMinutes: Int
    public let newBadges: Int
    public let currentStreak: Int
    public let highlight: String
    public let weeklyBreakdown: [ActivityBreakdown]
    public let vsLastWeek: ComparisonMetrics
    public let recommendations: [String]

    public init(
        dateRange: String,
        childName: String,
        lessonsCompleted: Int,
        totalMinutes: Int,
        newBadges: Int,
        currentStreak: Int,
        highlight: String,
        weeklyBreakdown: [ActivityBreakdown],
        vsLastWeek: ComparisonMetrics,
        recommendations: [String]
    ) {
        self.dateRange = dateRange
        self.childName = childName
        self.lessonsCompleted = lessonsCompleted
        self.totalMinutes = totalMinutes
        self.newBadges = newBadges
        self.currentStreak = currentStreak
        self.highlight = highlight
        self.weeklyBreakdown = weeklyBreakdown
        self.vsLastWeek = vsLastWeek
        self.recommendations = recommendations
    }
}

public struct ActivityBreakdown {
    public let activityType: String
    public let minutes: Int
    public let percentage: Double
    public let color: Color

    public init(activityType: String, minutes: Int, percentage: Double, color: Color) {
        self.activityType = activityType
        self.minutes = minutes
        self.percentage = percentage
        self.color = color
    }
}

public struct ComparisonMetrics {
    public let lessonsChange: String
    public let lessonsPercentage: Double
    public let timeChange: String
    public let timePercentage: Double
    public let badgesChange: String
    public let badgesPercentage: Double

    public init(
        lessonsChange: String,
        lessonsPercentage: Double,
        timeChange: String,
        timePercentage: Double,
        badgesChange: String,
        badgesPercentage: Double
    ) {
        self.lessonsChange = lessonsChange
        self.lessonsPercentage = lessonsPercentage
        self.timeChange = timeChange
        self.timePercentage = timePercentage
        self.badgesChange = badgesChange
        self.badgesPercentage = badgesPercentage
    }
}

// MARK: - Helper

private func dateRangeString(from startDate: Date, to endDate: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"

    let start = formatter.string(from: startDate)
    formatter.dateFormat = "MMM d, yyyy"
    let end = formatter.string(from: endDate)

    return "\(start) - \(end)"
}
