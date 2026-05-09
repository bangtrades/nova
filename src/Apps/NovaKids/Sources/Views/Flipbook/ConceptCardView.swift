import SwiftUI
import NovaCore
import UIKit

/// Concept card view — a workbook explanation page rendered inside
/// the `LessonBookReaderShell` workbook chrome.
///
/// The card no longer nests a chalkboard surface; the workbook
/// shell already provides the paper-page silhouette. Concept
/// content is laid out as a worksheet: a small sun-circle + title
/// header, a paper-toned diagram / hero panel, and the "big idea"
/// rendered on a `LessonBookPageSurface` (workbook mood).
///
/// Read-aloud lives at the workbook shell level, not on the card —
/// `FlipbookView` owns the lesson-level Read Page button so a kid
/// has one obvious way to hear the current page. The in-card
/// speaker sticker that previously duplicated it has been removed.
public struct ConceptCardView: View {
    /// The card to display.
    let card: Card

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    public init(card: Card) {
        self.card = card
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                pageHeader

                ViewThatFits(in: .horizontal) {
                    // Wide workbook layout (iPad landscape): diagram /
                    // illustration on the leading edge, "big idea"
                    // page alongside. The minWidth gate keeps narrow
                    // sizes off this branch.
                    HStack(alignment: .top, spacing: Spacing.lg) {
                        heroPanel
                            .frame(width: 320)
                            .frame(maxHeight: 260)

                        explanationNote
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minWidth: 880, alignment: .leading)

                    // Stacked workbook layout (iPad portrait, narrow
                    // splits): diagram on top, big-idea page below.
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        heroPanel
                            .frame(maxHeight: 240)

                        explanationNote
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Concept Card")
        .accessibilityValue(card.content.explanation ?? "")
    }

    private var surfaceTitle: String {
        if let title = card.content.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           title.isEmpty == false {
            return title
        }
        return "Concept"
    }

    /// Workbook page header — a sun-circle "lesson dot" plus the
    /// concept title. Replaces the chalkboard surface header that
    /// previously labelled the card; sized to read as a worksheet
    /// page-top title inside the open book.
    private var pageHeader: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            Circle()
                .fill(NovaPalette.classroomSun)
                .overlay(
                    Circle().stroke(NovaPalette.classroomInk.opacity(0.55), lineWidth: 1)
                )
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            Text(surfaceTitle)
                .font(NovaPalette.headingFont())
                .foregroundStyle(NovaPalette.classroomInk)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xs)
    }

    /// Diagram / hero panel for the concept card. Prefers the painted
    /// `LessonArtSlot.conceptChalkDiagramBoard` asset (canonical:
    /// `lesson_concept_chalk_diagram_board_45`; legacy:
    /// `lesson_chalkpanel_45_landscape`) so the diagram reads as a
    /// labeled workbook illustration; falls back to a paper-and-sky
    /// gradient with a lightbulb glyph when no painted asset has
    /// shipped. Either path keeps the lightbulb cue + "Concept"
    /// caption visible above the bitmap so a four-year-old still
    /// sees the workbook label without reading.
    private var heroPanel: some View {
        CardHeroImage(url: card.imageURL) {
            ZStack {
                if let boardAsset = LessonArtSlot.conceptChalkDiagramBoard.resolvedName {
                    Image(boardAsset)
                        .resizable()
                        .scaledToFill()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                } else {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            NovaPalette.classroomPaper,
                            NovaPalette.classroomSky.opacity(0.22),
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                VStack(spacing: Spacing.sm) {
                    Image(systemName: "lightbulb.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(NovaPalette.classroomSun)
                        .accessibilityHidden(true)

                    Text("Concept")
                        .font(NovaPalette.captionFont().weight(.bold))
                        .foregroundStyle(NovaPalette.classroomInk.opacity(0.75))
                }
                .padding(Spacing.lg)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 260)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Spacing.md, style: .continuous)
                .stroke(NovaPalette.classroomInk.opacity(0.40), lineWidth: 2)
        }
        .shadow(color: NovaPalette.classroomInk.opacity(0.16), radius: 4, x: 0, y: 2)
        .accessibilityHidden(card.imageURL == nil)
    }

    /// "Big idea" workbook page: the explanation rendered on a paper
    /// note pinned inside the chalkboard surface, with a small
    /// sun-circle + ruled cap that nods to a worksheet header.
    @ViewBuilder
    private var explanationNote: some View {
        if let explanation = card.content.explanation {
            LessonBookPageSurface(mood: .workbook) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(NovaPalette.classroomSun)
                            .overlay {
                                Circle().stroke(NovaPalette.classroomInk.opacity(0.55), lineWidth: 1)
                            }
                            .frame(width: 12, height: 12)
                            .accessibilityHidden(true)

                        Capsule(style: .continuous)
                            .fill(NovaPalette.classroomInk.opacity(0.20))
                            .frame(width: 92, height: 4)
                            .accessibilityHidden(true)
                    }

                    Text(explanation)
                        .font(NovaPalette.largeBodyFont())
                        .foregroundStyle(NovaPalette.classroomInk)
                        .lineSpacing(4)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }

}

#Preview {
    let card = Card(
        id: UUID(),
        lessonId: UUID(),
        type: .concept,
        sortOrder: 1,
        content: Card.CardContent(
            title: "Concept",
            explanation: "AI learns by looking at many examples and finding patterns."
        ),
        voiceScript: "AI learns by looking at many examples and finding patterns."
    )

    ConceptCardView(card: card)
}
