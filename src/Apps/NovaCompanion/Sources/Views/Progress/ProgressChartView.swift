import SwiftUI

/// Bar chart showing weekly learning activity.
public struct ProgressChartView: View {
    let activities: [DailyActivity]

    private var maxMinutes: Int {
        (activities.map { $0.minutesSpent }.max() ?? 30) + 10
    }

    public init(activities: [DailyActivity]) {
        self.activities = activities
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Activity")
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)

            VStack(spacing: 0) {
                // Chart
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(activities, id: \.date) { activity in
                        VStack(spacing: 4) {
                            // Bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(CompanionPalette.novaBlue)
                                .frame(
                                    height: CGFloat(activity.minutesSpent) / CGFloat(maxMinutes) * 120
                                )

                            // Day Label
                            Text(dayLabel(activity.date))
                                .font(CompanionPalette.captionFont())
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 160)
                .padding(.vertical, 16)
                .padding(.horizontal, 8)
                .background(Color.white)

                Divider()

                // Legend
                HStack(spacing: 16) {
                    Image(systemName: "square.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(CompanionPalette.novaBlue)

                    Text("Minutes spent learning")
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(12)
            }
            .background(CompanionPalette.companionCard)
            .border(CompanionPalette.companionBorder, width: 1)
            .cornerRadius(8)
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

#Preview {
    ProgressChartView(activities: [
        DailyActivity(date: Calendar.current.date(byAdding: .day, value: -6, to: Date())!, minutesSpent: 15),
        DailyActivity(date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!, minutesSpent: 22),
        DailyActivity(date: Calendar.current.date(byAdding: .day, value: -4, to: Date())!, minutesSpent: 18),
        DailyActivity(date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, minutesSpent: 31),
        DailyActivity(date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, minutesSpent: 25),
        DailyActivity(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, minutesSpent: 20),
        DailyActivity(date: Date(), minutesSpent: 28),
    ])
    .padding(16)
    .background(CompanionPalette.companionBackground)
}
