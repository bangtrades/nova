import SwiftUI
import NovaCore

/// Header for the flipbook view.
///
/// Shows lesson title, back button, and optional lesson description.
public struct FlipbookHeader: View {
    /// The lesson being displayed.
    let lesson: Lesson

    /// Callback for back button tap.
    let onBack: () -> Void

    @Environment(\.colorScheme) var colorScheme

    public init(lesson: Lesson, onBack: @escaping () -> Void) {
        self.lesson = lesson
        self.onBack = onBack
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .accessibilityHidden(true)

                        Text("Back")
                    }
                    .foregroundStyle(NovaPalette.novaBlue)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        colorScheme == .dark
                            ? NovaPalette.novaBlue.opacity(0.2)
                            : NovaPalette.novaBlue.opacity(0.1)
                    )
                    .cornerRadius(8)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(lesson.title)
                        .font(NovaPalette.smallHeadingFont())
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: index < lesson.difficulty ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(
                                    index < lesson.difficulty
                                        ? NovaPalette.novaYellow
                                        : NovaPalette.ink.opacity(0.3)
                                )
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityHidden(true)
                }
            }

            if !lesson.description.isEmpty {
                Text(lesson.description)
                    .font(NovaPalette.captionFont())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(NovaPalette.novaCardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Flipbook: \(lesson.title)")
        .accessibilityValue(lesson.description)
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

    FlipbookHeader(lesson: lesson) {
        print("Back tapped")
    }
    .padding(20)
}
