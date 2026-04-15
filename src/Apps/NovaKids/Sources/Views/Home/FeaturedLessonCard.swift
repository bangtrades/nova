import SwiftUI
import NovaCore

/// Hero card displaying a featured lesson with large thumbnail.
///
/// Shows a prominent lesson card with title, description, and difficulty indicator.
/// Used as the main call-to-action on the home screen.
public struct FeaturedLessonCard: View {
    /// The lesson to display.
    let lesson: Lesson

    /// Callback when the card is tapped.
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    public init(lesson: Lesson, onTap: @escaping () -> Void) {
        self.lesson = lesson
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail area with placeholder
                ZStack {
                    // Background gradient
                    LinearGradient(
                        gradient: Gradient(colors: [
                            NovaPalette.novaBlue.opacity(0.3),
                            NovaPalette.novaOrange.opacity(0.2),
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Icon placeholder
                    VStack(spacing: 12) {
                        Image(systemName: "book.fill")
                            .font(.largeTitle)
                            .foregroundStyle(NovaPalette.novaBlue)
                            .accessibilityHidden(true)

                        Text("Featured Lesson")
                            .font(NovaPalette.captionFont())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 200)

                // Content area
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text(lesson.title)
                            .font(NovaPalette.headingFont())
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer()

                        // Difficulty stars
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { index in
                                Image(systemName: index < lesson.difficulty ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundStyle(
                                        index < lesson.difficulty
                                            ? NovaPalette.novaYellow
                                            : Color.gray.opacity(0.3)
                                    )
                                    .accessibilityHidden(true)
                            }
                        }
                        .accessibilityHidden(true)
                    }

                    Text(lesson.description)
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack {
                        Text("Tap to start")
                            .font(NovaPalette.smallHeadingFont())
                            .foregroundStyle(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(NovaPalette.novaOrange)
                            .cornerRadius(8)

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(NovaPalette.novaOrange)
                            .accessibilityHidden(true)
                    }
                }
                .padding(20)
                .background(NovaPalette.novaCardBackground)
            }
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
            .scaleEffect(reduceMotion ? 1.0 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Featured: \(lesson.title)")
        .accessibilityValue("\(lesson.description)")
        .accessibilityHint("Double tap to start this lesson")
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

    FeaturedLessonCard(lesson: lesson) {
        print("Tapped")
    }
    .padding(20)
}
