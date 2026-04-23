import SwiftUI
import NovaCore

/// Header for the flipbook view.
///
/// Shows the card type as a Bangers display label with a category-color bar,
/// the lesson title (rounded subhead), difficulty stars, and a back button.
///
/// Updated in S11-11 to lean on the 3+1 palette and the comic-book
/// card-type identity. The header no longer carries its own card
/// background — it floats on `novaBackground` so the flipbook reads as a
/// single surface.
public struct FlipbookHeader: View {
    /// The lesson being displayed.
    let lesson: Lesson

    /// The currently-visible card's type, or nil when no card is active.
    ///
    /// Drives the Bangers label + color bar. Kept optional so the header
    /// renders cleanly during the brief window before the first card
    /// appears or when the lesson has no cards.
    let cardType: Card.CardType?

    /// Callback for back button tap.
    let onBack: () -> Void

    public init(
        lesson: Lesson,
        cardType: Card.CardType?,
        onBack: @escaping () -> Void
    ) {
        self.lesson = lesson
        self.cardType = cardType
        self.onBack = onBack
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Top row — back button / lesson title / difficulty stars
            HStack(spacing: Spacing.sm) {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .accessibilityHidden(true)
                        Text("Back")
                            .font(NovaPalette.smallHeadingFont())
                    }
                    .foregroundStyle(NovaPalette.ink)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(NovaPalette.ink, lineWidth: 2)
                    )
                }
                .accessibilityLabel("Back to lessons")

                Spacer()

                Text(lesson.title)
                    .font(NovaPalette.smallHeadingFont())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(
                            systemName: index < lesson.difficulty ? "star.fill" : "star"
                        )
                        .font(.caption2)
                        .foregroundStyle(
                            index < lesson.difficulty
                                ? NovaPalette.sun
                                : NovaPalette.ink.opacity(0.3)
                        )
                        .accessibilityHidden(true)
                    }
                }
                .accessibilityHidden(true)
            }

            // Card-type badge — Bangers label + category color bar.
            //
            // The bar is the comic-book "strip divider" under the label and
            // borrows the per-type rainbow from `NovaPalette.Category.*`.
            // When no card is active yet, this whole block is omitted so
            // the header doesn't flash a default color.
            if let cardType {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cardTypeLabel(cardType))
                        .font(NovaPalette.displayFont(size: 22))
                        .foregroundStyle(NovaPalette.ink)
                        .tracking(1.5)

                    Rectangle()
                        .fill(categoryColor(cardType))
                        .frame(width: 64, height: 4)
                        .cornerRadius(2)
                }
            }

            if !lesson.description.isEmpty {
                Text(lesson.description)
                    .font(NovaPalette.captionFont())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Flipbook: \(lesson.title)")
        .accessibilityValue(accessibilityValueText)
    }

    /// Builds the combined VoiceOver value so the card type, difficulty, and
    /// description are spoken together rather than as three separate swipes.
    private var accessibilityValueText: String {
        var parts: [String] = []
        if let cardType {
            parts.append("\(cardTypeLabel(cardType).capitalized) card")
        }
        parts.append("Difficulty \(lesson.difficulty) of 3")
        if !lesson.description.isEmpty {
            parts.append(lesson.description)
        }
        return parts.joined(separator: ". ")
    }

    private func cardTypeLabel(_ type: Card.CardType) -> String {
        switch type {
        case .story: return "STORY"
        case .concept: return "CONCEPT"
        case .experiment: return "EXPERIMENT"
        case .quiz: return "QUIZ"
        case .voice: return "VOICE"
        }
    }

    /// Maps card type → category rainbow color. The mapping mirrors how the
    /// card views themselves are tinted (story≈narrative purple,
    /// concept≈analytical blue, experiment≈build green, quiz≈high-energy
    /// orange matching QuizCardView from S11-06, voice≈character pink).
    private func categoryColor(_ type: Card.CardType) -> Color {
        switch type {
        case .story: return NovaPalette.Category.purple
        case .concept: return NovaPalette.Category.blue
        case .experiment: return NovaPalette.Category.green
        case .quiz: return NovaPalette.Category.orange
        case .voice: return NovaPalette.Category.pink
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

    VStack(spacing: 24) {
        FlipbookHeader(lesson: lesson, cardType: .story) {
            print("Back tapped")
        }
        FlipbookHeader(lesson: lesson, cardType: .quiz) {
            print("Back tapped")
        }
        FlipbookHeader(lesson: lesson, cardType: .experiment) {
            print("Back tapped")
        }
    }
    .padding(20)
    .background(NovaPalette.novaBackground)
}
