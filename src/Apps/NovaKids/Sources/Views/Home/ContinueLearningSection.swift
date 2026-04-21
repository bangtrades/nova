import SwiftUI
import NovaCore

/// Section showing current learning progress.
///
/// Displays the current lesson title, a gradient progress bar, and today's
/// time + streak. As of S11-05 the lesson block is wrapped in a `NovaCard`
/// with a blue accent stripe (Category.blue is our "learning / progress"
/// color) and the section header uses the Bangers display font. The progress
/// bar is now width-relative (GeometryReader) so it fills the card regardless
/// of the screen size.
public struct ContinueLearningSection: View {
    /// The current lesson being worked on.
    let currentLesson: Lesson?

    /// Progress percentage (0-1).
    let progress: Double

    public init(currentLesson: Lesson?, progress: Double) {
        self.currentLesson = currentLesson
        self.progress = progress
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Continue Learning")
                .font(NovaPalette.displayFont(size: 24))
                .foregroundStyle(NovaPalette.ink)

            if let lesson = currentLesson {
                activeLessonCard(lesson)
            } else {
                emptyState
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Continue Learning")
        .accessibilityValue(
            currentLesson.map { "\($0.title), \(Int(progress * 100))% complete" }
                ?? "No lesson in progress"
        )
    }

    // MARK: - Subviews

    private func activeLessonCard(_ lesson: Lesson) -> some View {
        NovaCard(accent: NovaPalette.Category.blue) {
            VStack(alignment: .leading, spacing: Spacing.sm + 4) {
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(lesson.title)
                            .font(NovaPalette.smallHeadingFont())
                            .foregroundStyle(NovaPalette.ink)
                            .lineLimit(2)

                        Text("\(Int(progress * 100))% complete")
                            .font(NovaPalette.captionFont())
                            .foregroundStyle(NovaPalette.ink.opacity(0.7))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(NovaPalette.coral)
                        .accessibilityHidden(true)
                }

                progressBar

                HStack(spacing: Spacing.md) {
                    metaItem(icon: "clock.fill", tint: NovaPalette.Category.blue, label: "12 min today", voLabel: "12 minutes spent today")
                    Spacer()
                    metaItem(icon: "flame.fill", tint: NovaPalette.Category.orange, label: "3 day streak", voLabel: "3 day learning streak")
                }
            }
        }
    }

    /// GeometryReader-driven progress bar — fills the container instead of a
    /// hardcoded 280pt which only looked right on iPhone.
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(NovaPalette.ink.opacity(0.15))

                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [NovaPalette.Category.green, NovaPalette.Category.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .frame(height: 12)
        .accessibilityHidden(true) // Value is surfaced on the section element.
    }

    private func metaItem(icon: String, tint: Color, label: String, voLabel: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            Text(label)
                .font(NovaPalette.captionFont())
                .foregroundStyle(NovaPalette.ink.opacity(0.7))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voLabel)
    }

    private var emptyState: some View {
        NovaCard {
            Text("No lesson in progress")
                .font(NovaPalette.bodyFont())
                .foregroundStyle(NovaPalette.ink.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    let lesson = Lesson(
        id: UUID(),
        pathId: UUID(),
        userId: UUID(),
        title: "What Makes AI Smart?",
        description: "Learn how artificial intelligence learns from data",
        thumbnailURL: nil,
        difficulty: 1,
        sourceURL: nil,
        aiAnalysis: nil,
        status: .published,
        sortOrder: 1,
        createdAt: Date(),
        publishedAt: Date(),
        cards: []
    )

    VStack(spacing: Spacing.lg) {
        ContinueLearningSection(currentLesson: lesson, progress: 0.35)
        ContinueLearningSection(currentLesson: nil, progress: 0)
    }
    .padding(Spacing.lg)
    .background(NovaPalette.novaBackground)
}
