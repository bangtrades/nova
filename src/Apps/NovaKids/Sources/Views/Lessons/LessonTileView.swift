import SwiftUI
import NovaCore

/// Individual lesson tile for masonry grid.
///
/// Displays lesson thumbnail, title, difficulty, and completion status.
/// Supports large dynamic type and VoiceOver.
public struct LessonTileView: View {
    /// The lesson to display.
    let lesson: Lesson

    /// Whether the lesson is complete.
    let isComplete: Bool

    /// Callback when tapped.
    let onTap: () -> Void

    public init(lesson: Lesson, isComplete: Bool = false, onTap: @escaping () -> Void) {
        self.lesson = lesson
        self.isComplete = isComplete
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    // Thumbnail
                    ZStack {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                NovaPalette.novaBlue.opacity(0.4),
                                NovaPalette.novaOrange.opacity(0.3),
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        VStack(spacing: 8) {
                            Image(systemName: "book.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                                .accessibilityHidden(true)

                            Text("Lesson")
                                .font(NovaPalette.captionFont())
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .frame(height: 140)

                    // Content
                    VStack(alignment: .leading, spacing: 10) {
                        Text(lesson.title)
                            .font(NovaPalette.smallHeadingFont())
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Difficulty stars
                        HStack(spacing: 3) {
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
                            Spacer()
                        }
                        .accessibilityHidden(true)

                        Text(lesson.description)
                            .font(NovaPalette.captionFont())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(NovaPalette.novaCardBackground)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                // Completion badge
                if isComplete {
                    ZStack {
                        Circle()
                            .fill(NovaPalette.novaGreen)
                            .frame(width: 36, height: 36)

                        Image(systemName: "checkmark")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                    }
                    .padding(8)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(lesson.title)
        .accessibilityValue("\(lesson.difficulty) stars\(isComplete ? ", completed" : "")")
        .accessibilityHint("Double tap to open this lesson")
    }
}

#Preview {
    let lesson = Lesson(
        id: UUID(),
        pathId: UUID(),
        userId: UUID(),
        title: "What Makes AI Smart?",
        description: "Learn how AI learns from data",
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

    VStack(spacing: 16) {
        LessonTileView(lesson: lesson, isComplete: false) {
            print("Tapped")
        }

        LessonTileView(lesson: lesson, isComplete: true) {
            print("Tapped")
        }
    }
    .padding(20)
}
