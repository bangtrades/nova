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
            // Top row — back chalk-paper label on the left, difficulty
            // sticker-stars on the right. Title sits on its own row below
            // so the placard reads as a single dominant lesson label.
            HStack(spacing: Spacing.sm) {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .accessibilityHidden(true)
                        Text("Back")
                            .font(NovaPalette.smallHeadingFont())
                    }
                    .foregroundStyle(NovaPalette.classroomInk)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        NovaPalette.classroomPaper,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(NovaPalette.classroomInk.opacity(0.75), lineWidth: 2)
                    )
                    .frame(minWidth: 64, minHeight: 64)
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityLabel("Back to lessons")

                Spacer()

                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(
                            systemName: index < lesson.difficulty ? "star.fill" : "star"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            index < lesson.difficulty
                                ? NovaPalette.classroomSun
                                : NovaPalette.classroomInk.opacity(0.25)
                        )
                        .accessibilityHidden(true)
                    }
                }
                .accessibilityHidden(true)
            }

            // Lesson title — placard headline. One line with minimum scale
            // so longer titles fit on iPad portrait without overflowing.
            Text(lesson.title)
                .font(NovaPalette.headingFont())
                .foregroundStyle(NovaPalette.classroomInk)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Subject tab + description — the card type renders as a small
            // classroom-color subject label next to the lesson description,
            // so the kid sees "what this card teaches" at a glance.
            HStack(alignment: .top, spacing: Spacing.sm) {
                if let cardType {
                    Text(cardTypeLabel(cardType))
                        .font(NovaPalette.captionFont().weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(NovaPalette.classroomInk)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(
                            categoryColor(cardType).opacity(0.28),
                            in: Capsule(style: .continuous)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(categoryColor(cardType).opacity(0.55), lineWidth: 1)
                        )
                        .fixedSize(horizontal: true, vertical: false)
                }

                if let description = lesson.description, description.isEmpty == false {
                    Text(description)
                        .font(NovaPalette.captionFont())
                        .foregroundStyle(NovaPalette.classroomInk.opacity(0.7))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
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
        if let description = lesson.description, description.isEmpty == false {
            parts.append(description)
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
        case .video: return "VIDEO"
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
        case .video: return NovaPalette.Category.blue
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
