import SwiftUI

/// Timeline view of recent activity across all children.
public struct ActivityFeedView: View {
    let items: [ActivityFeedItem]

    public init(items: [ActivityFeedItem]) {
        self.items = items
    }

    public var body: some View {
        if items.isEmpty {
            EmptyStateView(
                icon: "calendar",
                title: "No Activity Yet",
                message: "Activity will appear here as your children learn"
            )
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("Recent Activity")
                    .font(CompanionPalette.headingFont())
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Divider()

                VStack(spacing: 0) {
                    ForEach(items) { item in
                        activityRow(item)
                        if item.id != items.last?.id {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .background(CompanionPalette.companionCard)
            .border(CompanionPalette.companionBorder, width: 1)
            .cornerRadius(8)
        }
    }

    private func activityRow(_ item: ActivityFeedItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(CompanionPalette.novaBlue)
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.childName)
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)

                    Text(item.action)
                        .font(CompanionPalette.secondaryBodyFont())
                        .foregroundStyle(.secondary)
                }

                Text(item.lessonTitle)
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(timeAgoString(item.timestamp))
                .font(CompanionPalette.captionFont())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .contentShape(Rectangle())
    }

    private func timeAgoString(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if minutes < 60 {
            return "\(minutes)m ago"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else {
            return "\(days)d ago"
        }
    }
}

#Preview {
    ActivityFeedView(items: [
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
    ])
    .padding(16)
    .background(CompanionPalette.companionBackground)
}
