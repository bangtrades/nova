import SwiftUI

/// List of recent learning sessions with details.
public struct SessionHistoryView: View {
    let sessions: [SessionHistoryItem]

    public init(sessions: [SessionHistoryItem]) {
        self.sessions = sessions
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)

            if sessions.isEmpty {
                EmptyStateView(
                    icon: "calendar",
                    title: "No Sessions",
                    message: "Sessions will appear here as your children learn"
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(sessions) { session in
                        sessionRow(session)
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: SessionHistoryItem) -> some View {
        HStack(spacing: 12) {
            // Status Icon
            Image(systemName: session.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(session.succeeded ? CompanionPalette.statusPublished : .gray)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.childName)
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)

                    Text(session.lessonTitle)
                        .font(CompanionPalette.secondaryBodyFont())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    Label("\(session.duration) min", systemImage: "clock.fill")
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)

                    Label("\(session.cardsInteracted) cards", systemImage: "square.fill")
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(formatTime(session.date))
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(CompanionPalette.companionCard)
        .border(CompanionPalette.companionBorder, width: 1)
        .cornerRadius(8)
    }

    private func formatTime(_ date: Date) -> String {
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
    SessionHistoryView(sessions: [
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
    ])
    .padding(16)
    .background(CompanionPalette.companionBackground)
}
