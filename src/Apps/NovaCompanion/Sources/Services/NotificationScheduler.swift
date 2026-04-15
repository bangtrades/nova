import Foundation
import UIKit
import UserNotifications

/// Local notification scheduling for weekly reports, badges, streaks, and lessons.
public class NotificationScheduler {
    public static let shared = NotificationScheduler()

    private init() {}

    // MARK: - Notification Categories

    private enum NotificationCategory: String {
        case weeklyReport = "WEEKLY_REPORT"
        case badgeEarned = "BADGE_EARNED"
        case streakAtRisk = "STREAK_AT_RISK"
        case lessonComplete = "LESSON_COMPLETE"
    }

    // MARK: - Public Methods

    /// Request user notification permissions.
    public func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }

    /// Schedule weekly report reminder (default: Sunday 9am).
    public func scheduleWeeklyReport(dayOfWeek: Int = 0, hour: Int = 9) {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Report Ready"
        content.body = "See how your child learned this week"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.categoryIdentifier = NotificationCategory.weeklyReport.rawValue
        content.userInfo = ["type": "weeklyReport"]

        let triggerDate = nextDateForDayOfWeek(dayOfWeek, hour: hour)
        let components = Calendar.current.dateComponents([.weekday, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "weekly-report",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule weekly report: \(error)")
            }
        }
    }

    /// Schedule badge earned notification.
    public func scheduleBadgeAlert(childName: String, badgeName: String) {
        let content = UNMutableNotificationContent()
        content.title = "New Badge Earned!"
        content.body = "\(childName) earned '\(badgeName)' 🎉"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.categoryIdentifier = NotificationCategory.badgeEarned.rawValue
        content.userInfo = [
            "type": "badgeEarned",
            "childName": childName,
            "badgeName": badgeName
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "badge-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule badge alert: \(error)")
            }
        }
    }

    /// Schedule streak reminder if no activity yesterday.
    public func scheduleStreakReminder(childName: String, currentStreak: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Keep the Streak Going!"
        content.body = "\(childName)'s \(currentStreak)-day streak needs practice today"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.categoryIdentifier = NotificationCategory.streakAtRisk.rawValue
        content.userInfo = [
            "type": "streakAtRisk",
            "childName": childName,
            "streak": currentStreak
        ]

        // Daily at 5pm
        var components = DateComponents()
        components.hour = 17
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "streak-reminder-\(childName)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule streak reminder: \(error)")
            }
        }
    }

    /// Schedule lesson completion notification.
    public func scheduleLessonComplete(childName: String, lessonTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "Lesson Completed"
        content.body = "\(childName) finished '\(lessonTitle)'"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.categoryIdentifier = NotificationCategory.lessonComplete.rawValue
        content.userInfo = [
            "type": "lessonComplete",
            "childName": childName,
            "lessonTitle": lessonTitle
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "lesson-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule lesson complete notification: \(error)")
            }
        }
    }

    /// Cancel all pending notifications.
    public func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Cancel a specific notification by identifier.
    public func cancel(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Private Methods

    private func nextDateForDayOfWeek(_ dayOfWeek: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.weekday = dayOfWeek + 1 // 1-7 where 1=Sunday
        components.hour = hour
        components.minute = 0
        components.second = 0

        let calendar = Calendar.current
        let nextDate = calendar.nextDate(
            after: Date(),
            matching: components,
            matchingPolicy: .nextTime
        )

        return nextDate ?? Date().addingTimeInterval(86400) // Fallback to tomorrow
    }
}
