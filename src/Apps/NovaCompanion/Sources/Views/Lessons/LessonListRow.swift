import SwiftUI
import NovaCore

/// Row view for a lesson in the lesson list.
public struct LessonListRow: View {
    let lesson: Lesson
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onPublish: (Bool) -> Void

    @State private var showingDeleteConfirmation = false

    private var statusColor: Color {
        switch lesson.status {
        case .draft:
            return CompanionPalette.statusDraft
        case .published:
            return CompanionPalette.statusPublished
        case .review:
            return CompanionPalette.statusDraft
        case .generating:
            return CompanionPalette.novaOrange
        }
    }

    private var statusText: String {
        switch lesson.status {
        case .draft:
            return "Draft"
        case .published:
            return "Published"
        case .review:
            return "Review"
        case .generating:
            return "Generating"
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Thumbnail/Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(CompanionPalette.pathColor(for: lesson.id.uuidString).opacity(0.2))

                    Image(systemName: "book.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(CompanionPalette.pathColor(for: lesson.id.uuidString))
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title)
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Badge(text: statusText, color: statusColor)

                        if lesson.difficulty > 0 {
                            HStack(spacing: 2) {
                                ForEach(0..<lesson.difficulty, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(CompanionPalette.novaYellow)
                                }
                            }
                        }
                    }
                }

                Spacer()

                Menu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }

                    Divider()

                    if lesson.status == .published {
                        Button(action: { onPublish(false) }) {
                            Label("Unpublish", systemImage: "lock.open")
                        }
                    } else {
                        Button(action: { onPublish(true) }) {
                            Label("Publish", systemImage: "lock")
                        }
                    }

                    Divider()

                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            // Metadata Row
            HStack(spacing: 16) {
                Text(lesson.cards?.count ?? 0 > 0 ? "\(lesson.cards?.count ?? 0) cards" : "No cards")
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)

                Divider()
                    .frame(height: 12)

                Text(formatDate(lesson.createdAt))
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(12)
        .background(CompanionPalette.companionCard)
        .border(CompanionPalette.companionBorder, width: 1)
        .cornerRadius(8)
        .confirmationDialog("Delete Lesson", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \"\(lesson.title)\"? This cannot be undone.")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "Modified \(formatter.string(from: date))"
    }
}

private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(CompanionPalette.smallCaptionFont())
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(4)
    }
}

#Preview {
    VStack(spacing: 12) {
        LessonListRow(
            lesson: Lesson(
                userId: UUID(),
                title: "What is AI?",
                description: "An introduction",
                difficulty: 1,
                status: .published,
                sortOrder: 1,
                publishedAt: Date().addingTimeInterval(-86400)
            ),
            onEdit: {},
            onDelete: {},
            onPublish: { _ in }
        )

        LessonListRow(
            lesson: Lesson(
                userId: UUID(),
                title: "Training Models",
                description: "How to train",
                difficulty: 2,
                status: .draft,
                sortOrder: 2
            ),
            onEdit: {},
            onDelete: {},
            onPublish: { _ in }
        )
    }
    .padding(16)
    .background(CompanionPalette.companionBackground)
}
