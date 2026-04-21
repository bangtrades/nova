import SwiftUI
import NovaCore

/// Hero card displaying a featured lesson with large thumbnail.
///
/// Shows a prominent lesson card with title, description, difficulty stars,
/// and a "Start lesson" CTA. Used as the main call-to-action on the home
/// screen. As of S11-05 the card composes through `NovaCard` (20pt radius +
/// 2pt ink stroke + paper shadow) and the title uses the Bangers display
/// font so it carries the comic-book feel.
///
/// ## Tap handling
///
/// In HomeView this card sits inside a `NavigationLink`, which owns the tap
/// target. We deliberately do **not** wrap the content in a `Button` here —
/// that would create a nested tap target and SwiftUI has to arbitrate which
/// one handles the touch, which can cause dropped taps on iPad. If a caller
/// wants tap handling without a NavigationLink, they can wrap the whole
/// `FeaturedLessonCard(...)` in a `Button { } label: { ... }`.
public struct FeaturedLessonCard: View {
    /// The lesson to display.
    let lesson: Lesson

    public init(lesson: Lesson) {
        self.lesson = lesson
    }

    public var body: some View {
        NovaCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Thumbnail area — gradient placeholder until real thumbnails land.
                thumbnail
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Title + difficulty stars
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Text(lesson.title)
                        .font(NovaPalette.displayFont(size: 28))
                        .foregroundStyle(NovaPalette.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    Spacer()

                    difficultyStars
                }

                // Description
                Text(lesson.description)
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(NovaPalette.ink.opacity(0.75))
                    .lineLimit(2)

                // CTA row — adopts the primary button language without being
                // an actual Button (the parent NavigationLink owns the tap).
                HStack {
                    Text("Tap to start")
                        .font(NovaPalette.bodyFont().weight(.semibold))
                        .foregroundStyle(NovaPalette.ink)
                        .padding(.vertical, Spacing.sm + 2)
                        .padding(.horizontal, Spacing.md)
                        .background(
                            NovaPalette.coral,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(NovaPalette.ink, lineWidth: 2)
                        }

                    Spacer()

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(NovaPalette.coral)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Featured: \(lesson.title)")
        .accessibilityValue(lesson.description)
        .accessibilityHint("Double tap to start this lesson")
    }

    // MARK: - Subviews

    private var thumbnail: some View {
        ZStack {
            LinearGradient(
                colors: [
                    NovaPalette.Category.blue.opacity(0.3),
                    NovaPalette.Category.orange.opacity(0.2),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: Spacing.sm + 4) {
                Image(systemName: "book.fill")
                    .font(.largeTitle)
                    .foregroundStyle(NovaPalette.Category.blue)
                    .accessibilityHidden(true)

                Text("Featured Lesson")
                    .font(NovaPalette.captionFont())
                    .foregroundStyle(NovaPalette.ink.opacity(0.7))
            }
        }
    }

    private var difficultyStars: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < lesson.difficulty ? "star.fill" : "star")
                    .font(.caption)
                    .foregroundStyle(
                        index < lesson.difficulty
                            ? NovaPalette.Category.yellow
                            : NovaPalette.ink.opacity(0.3)
                    )
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHidden(true)
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

    FeaturedLessonCard(lesson: lesson)
        .padding(Spacing.lg)
        .background(NovaPalette.novaBackground)
}
