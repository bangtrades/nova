import SwiftUI
import NovaCore
import UIKit

/// Story card view — a picture-book page rendered inside the
/// `LessonBookReaderShell` workbook chrome.
///
/// The card no longer nests a chalkboard surface; the workbook
/// shell already provides the paper-page silhouette. Story content
/// is laid out as a storybook page: a small bookmark + title header
/// at the top, the hero illustration framed as a paper-mat plate
/// with optional painted-frame asset, and narrative copy on a
/// `LessonBookPageSurface` (storybook mood).
///
/// Read-aloud lives at the workbook shell level, not on the card —
/// `FlipbookView` owns the lesson-level Read Page button so a kid
/// has one obvious way to hear the current page. The in-card
/// speaker sticker that previously duplicated it has been removed.
public struct StoryCardView: View {
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
                    // Wide layout (iPad landscape): illustration on
                    // the leading edge, narrative alongside. The
                    // minWidth gate keeps `ViewThatFits` from picking
                    // this branch on iPad portrait where the text
                    // column would squeeze.
                    HStack(alignment: .top, spacing: Spacing.lg) {
                        heroPlate
                            .frame(width: 320)
                            .frame(maxHeight: 260)

                        storyPage
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minWidth: 880, alignment: .leading)

                    // Stacked layout (iPad portrait, iPhone, narrow
                    // splits): illustration on top, narrative below.
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        heroPlate
                            .frame(maxHeight: 260)

                        storyPage
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(cardTitle) story card")
        .accessibilityValue(card.content.narrativeText ?? "")
    }

    /// Storybook page header — a small bookmark ribbon followed by
    /// the lesson title. Replaces the chalkboard surface header that
    /// previously labelled the card; sized to feel like a page-top
    /// title inside the open book rather than a top-of-screen badge.
    private var pageHeader: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            bookmarkOrnament
                .frame(width: 22, height: 36)
                .accessibilityHidden(true)

            Text(cardTitle)
                .font(NovaPalette.headingFont())
                .foregroundStyle(NovaPalette.classroomInk)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xs)
    }

    /// Painted bookmark sticker if the asset is in the bundle,
    /// otherwise a SwiftUI school-red ribbon stand-in. The lookup is
    /// routed through `LessonArtSlot.storyBookmark` so the canonical
    /// vault name (`lesson_story_bookmark_45`) wins automatically once
    /// the new artwork lands while the legacy `lesson_bookmark_45`
    /// imageset that ships today still resolves.
    @ViewBuilder
    private var bookmarkOrnament: some View {
        if let asset = LessonArtSlot.storyBookmark.resolvedName {
            Image(asset)
                .resizable()
                .scaledToFit()
        } else {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(NovaPalette.classroomSchoolRed.opacity(0.88))
                    .overlay(
                        Rectangle()
                            .stroke(NovaPalette.classroomInk.opacity(0.40), lineWidth: 1)
                    )

                // Small notched tail at the bottom of the ribbon.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 11, y: 6))
                    path.addLine(to: CGPoint(x: 22, y: 0))
                    path.closeSubpath()
                }
                .fill(NovaPalette.classroomPaper)
                .frame(height: 6)
            }
        }
    }

    private var cardTitle: String {
        if let title = card.content.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           title.isEmpty == false {
            return title
        }

        return "Story"
    }

    /// Hero illustration framed as a paper-mat plate pinned to the
    /// chalkboard. When the `LessonArtSlot.storyPictureFrame` slot
    /// resolves (canonical: `lesson_story_picture_frame_45`; legacy:
    /// `lesson_storybook_frame_45_landscape`), the inner image is
    /// inset to fit inside the painted border. When the slot does not
    /// resolve we drop the asset-specific inset and use a SwiftUI
    /// paper mat with normal `Spacing.sm` padding so the inner
    /// illustration fills the visible frame.
    private var heroPlate: some View {
        Group {
            if let frameAsset = LessonArtSlot.storyPictureFrame.resolvedName {
                assetFramedHero(asset: frameAsset)
            } else {
                swiftUIMattedHero
            }
        }
        .aspectRatio(1448.0 / 1086.0, contentMode: .fit)
        .accessibilityHidden(card.imageURL == nil)
    }

    /// Hero composed against the painted picture-book frame asset.
    /// The 68/52 horizontal/vertical inset is calibrated to land the
    /// inner illustration inside the painted border; do not edit
    /// those numerics without re-checking the frame artwork.
    private func assetFramedHero(asset: String) -> some View {
        ZStack {
            heroIllustration
                .padding(.horizontal, 68)
                .padding(.vertical, 52)

            Image(asset)
                .resizable()
                .scaledToFit()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// Hero composed against a SwiftUI paper mat for builds where the
    /// painted frame asset has not landed yet. Uses normal padding so
    /// the illustration fills the visible mat instead of inheriting
    /// the asset-frame inset.
    private var swiftUIMattedHero: some View {
        heroIllustration
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Spacing.md + 4, style: .continuous)
                    .fill(NovaPalette.classroomPaper.opacity(0.92))
            )
            .overlay {
                RoundedRectangle(cornerRadius: Spacing.md + 4, style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.55), lineWidth: 2)
            }
            .shadow(color: NovaPalette.classroomInk.opacity(0.18), radius: 6, x: 0, y: 3)
    }

    /// Inner hero illustration — the `CardHeroImage` async-loader plus
    /// a paper-toned fallback. Shared by both the asset-framed and
    /// SwiftUI-matted paths above. The placeholder prefers the
    /// painted `LessonArtSlot.storyBlankPicturePlaceholder` asset when
    /// available so a missing hero reads as a workbook blank-page
    /// invitation rather than a generic paper gradient.
    private var heroIllustration: some View {
        CardHeroImage(url: card.imageURL) {
            ZStack {
                if let placeholderAsset = LessonArtSlot.storyBlankPicturePlaceholder.resolvedName {
                    Image(placeholderAsset)
                        .resizable()
                        .scaledToFill()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                } else {
                    LinearGradient(
                        colors: [
                            NovaPalette.classroomSky.opacity(0.32),
                            NovaPalette.classroomPaper,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(NovaPalette.classroomInk)
                            .accessibilityHidden(true)

                        Text("Storybook")
                            .font(NovaPalette.captionFont().weight(.bold))
                            .foregroundStyle(NovaPalette.classroomInk.opacity(0.75))
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Spacing.md, style: .continuous))
    }

    /// Narrative text rendered on a storybook paper page so the copy
    /// reads as book text rather than dashboard text.
    @ViewBuilder
    private var storyPage: some View {
        if let narrative = card.content.narrativeText {
            LessonBookPageSurface(mood: .storybook) {
                Text(narrative)
                    .font(NovaPalette.largeBodyFont())
                    .foregroundStyle(NovaPalette.classroomInk)
                    .lineSpacing(4)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
        }
    }

}

#Preview {
    let card = Card(
        id: UUID(),
        lessonId: UUID(),
        type: .story,
        sortOrder: 0,
        content: Card.CardContent(
            title: "Story",
            narrativeText: "Once upon a time, a curious child asked, 'How do computers learn?'"
        ),
        voiceScript: "Once upon a time, a curious child asked, How do computers learn?"
    )

    StoryCardView(card: card)
}
