import SwiftUI
import UIKit

/// Open-book / workbook chrome that wraps `FlipbookView`'s card content.
///
/// The previous "card stage" treatment read as "card on a page" — a
/// rounded rectangle floating in screen chrome. The v2 lesson reader
/// instead reads as "kid sitting at a classroom desk with an open
/// workbook in front of them": a wooden desk slab at the bottom, a
/// wooden book cover behind two warm paper pages, a center
/// binding/gutter, page corner curls, a coral bookmark ribbon, and
/// drop shadows that anchor the book onto the desk.
///
/// All decorative layers are `allowsHitTesting(false)` and
/// `accessibilityHidden(true)` so swipe gestures pass through to the
/// underlying `TabView` and VoiceOver continues to traverse the live
/// card content rather than the chrome.
public struct LessonBookReaderShell<Content: View>: View {
    private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        ZStack {
            deskBase
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            bookSpread
                .frame(maxWidth: WorkbookArt.maxBookWidth)
                .padding(.bottom, WorkbookArt.bookDeskOverlap)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Wooden desk slab anchored at the bottom of the shell. The book
    /// silhouette overlaps it slightly so the book reads as resting
    /// *on* the desk rather than floating above it.
    private var deskBase: some View {
        VStack(spacing: 0) {
            Spacer()

            if hasAsset(WorkbookArt.deskImageName) {
                Image(WorkbookArt.deskImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .offset(y: WorkbookArt.deskOffsetBelowBaseline)
            } else {
                fallbackDeskBase
            }
        }
    }

    /// The open book itself — wooden cover behind two paper pages with
    /// a faint center crease. Content sits inside the page area.
    private var bookSpread: some View {
        GeometryReader { proxy in
            let insets = WorkbookPageInsets.landscape
            ZStack {
                if hasAsset(WorkbookArt.workbookImageName) {
                    Image(WorkbookArt.workbookImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                } else {
                    fallbackBookChrome
                }

                content()
                    .padding(.leading,  insets.leading(in: proxy.size))
                    .padding(.trailing, insets.trailing(in: proxy.size))
                    .padding(.top,      insets.top(in: proxy.size))
                    .padding(.bottom,   insets.bottom(in: proxy.size))
            }
        }
        .aspectRatio(WorkbookArt.aspectRatio, contentMode: .fit)
    }

    private var fallbackDeskBase: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    NovaPalette.classroomWood.opacity(0.85),
                    NovaPalette.classroomWood.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Rectangle()
                .fill(NovaPalette.classroomInk.opacity(0.32))
                .frame(height: 2)
        }
        .frame(height: 72)
    }

    private var fallbackBookChrome: some View {
        ZStack {
            bookCover
                .padding(-6)

            paperPages

            pageCorners

            bookmarkRibbon
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Wooden book cover — slightly larger than the paper pages so a
    /// rim of warm wood reads at the edges of the spread.
    private var bookCover: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        NovaPalette.classroomWood.opacity(0.86),
                        NovaPalette.classroomWood.opacity(0.62)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.45), lineWidth: 3)
            )
            .shadow(color: NovaPalette.classroomInk.opacity(0.35), radius: 18, x: 0, y: 12)
    }

    /// Two-page paper spread — a single paper rectangle with a faint
    /// center binding gradient. Reading "two pages" comes from the
    /// crease, not from a hard split, so card content can span freely
    /// without aligning to a hard gutter line.
    private var paperPages: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(NovaPalette.classroomPaper)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(NovaPalette.classroomInk.opacity(0.20), lineWidth: 2)
                )
                .shadow(color: NovaPalette.classroomInk.opacity(0.20), radius: 6, x: 0, y: 3)

            // Center binding gradient — darker at the gutter, fades to
            // paper on either side. Sized so it reads as a soft crease
            // without competing with the card content.
            LinearGradient(
                colors: [
                    NovaPalette.classroomInk.opacity(0.0),
                    NovaPalette.classroomInk.opacity(0.18),
                    NovaPalette.classroomInk.opacity(0.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 22)
            .blur(radius: 4)

            // A single hairline running the height of the page in the
            // exact gutter so the crease has a visible center even on
            // small iPad widths where the gradient blurs out.
            Rectangle()
                .fill(NovaPalette.classroomInk.opacity(0.18))
                .frame(width: 1)
        }
    }

    /// Tiny soft page-corner triangles in the upper corners of the
    /// spread. Decorative only — they read as the corner of a page
    /// curling up toward the reader.
    private var pageCorners: some View {
        VStack {
            HStack {
                pageCorner
                Spacer()
                pageCorner
                    .scaleEffect(x: -1, y: 1)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
    }

    private var pageCorner: some View {
        Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: 22, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 22))
            path.closeSubpath()
        }
        .fill(NovaPalette.classroomInk.opacity(0.10))
        .frame(width: 22, height: 22)
        .overlay {
            Path { path in
                path.move(to: CGPoint(x: 22, y: 0))
                path.addLine(to: CGPoint(x: 0, y: 22))
            }
            .stroke(NovaPalette.classroomInk.opacity(0.22), lineWidth: 1)
        }
    }

    /// Coral bookmark ribbon hanging from the top of the right page.
    /// Pure decoration — gives the book a kid-readable "I'm in a
    /// book right now" cue.
    private var bookmarkRibbon: some View {
        VStack {
            HStack {
                Spacer()

                ZStack(alignment: .top) {
                    Rectangle()
                        .fill(NovaPalette.classroomSchoolRed.opacity(0.88))
                        .frame(width: 18, height: 64)
                        .overlay(
                            Rectangle()
                                .stroke(NovaPalette.classroomInk.opacity(0.40), lineWidth: 1)
                        )

                    // Top end has a small notch so the ribbon reads as
                    // pinched into the book's spine rather than just a
                    // floating rectangle.
                    Triangle()
                        .fill(NovaPalette.classroomSchoolRed.opacity(0.88))
                        .frame(width: 18, height: 10)
                        .rotationEffect(.degrees(180))
                        .offset(y: -8)
                }
                .offset(y: -10)
                .padding(.trailing, 36)
            }

            Spacer()
        }
    }
}

// MARK: - Workbook art geometry

/// Hard-coded names + intrinsic geometry of the painted workbook art
/// in `Assets.xcassets`. Centralised here so the shell does not
/// sprinkle string literals or magic ratios across the file.
private enum WorkbookArt {
    /// Asset name for the open-book PNG with two paper pages, wooden
    /// cover, three yellow side tabs, and a red bookmark. Routed
    /// through `LessonArtSlot.readerWorkbookLandscape` so the slot
    /// candidate list owns the actual imageset name; falls back to
    /// the legacy literal when no candidate resolves so the existing
    /// `hasAsset(_:)` probe at the call site still produces the
    /// correct miss/hit signal.
    static var workbookImageName: String {
        LessonArtSlot.readerWorkbookLandscape.resolvedName
            ?? "lesson_workbook_45_landscape"
    }

    /// Asset name for the wooden desk slab the book rests on. Routed
    /// through `LessonArtSlot.readerDeskLandscape` (canonical:
    /// `lesson_reader_desk_45_landscape`; legacy:
    /// `lesson_desktop_45_landscape`).
    static var deskImageName: String {
        LessonArtSlot.readerDeskLandscape.resolvedName
            ?? "lesson_desktop_45_landscape"
    }

    /// Aspect ratio of the painted workbook PNG (width / height).
    /// Used by `aspectRatio(_, contentMode: .fit)` so the GeometryReader
    /// inside `bookSpread` reads the book's own rendered size, not
    /// the screen's, when computing content padding.
    static let aspectRatio: CGFloat = 1448.0 / 1086.0

    /// How far the painted desk slab is pushed below the shell's
    /// baseline. Positive values move the desk image down so only a
    /// rim shows under the book; negative values would lift it up
    /// behind the book.
    static let deskOffsetBelowBaseline: CGFloat = 48

    /// Maximum rendered width of the painted book, in points. The
    /// book is `.aspectRatio(_, .fit)` so without this cap a 12.9"
    /// iPad in landscape would render the book ~1200 pt wide and
    /// dominate the viewport. The 600 pt cap on `CardProgressDots`
    /// and the Prev/Next pair sets the visual rhythm; clamping the
    /// book to 1000 pt keeps it generous (still ~70% of a 12.9"
    /// landscape width) without competing with those controls.
    static let maxBookWidth: CGFloat = 1000

    /// Vertical distance the bottom edge of the book sits above the
    /// bottom of the shell, so the painted desk slab peeks under the
    /// book by exactly this much. Tuned by inspection of the desk
    /// PNG — large enough to read as "the book sits on a desk",
    /// small enough that the desk does not steal vertical room from
    /// the page area.
    static let bookDeskOverlap: CGFloat = 36
}

/// Inset model describing how much of the painted workbook PNG is
/// non-page chrome (book cover rim, yellow tabs, bookmark, bottom
/// curve), expressed as fractions of the rendered book frame.
///
/// The shell uses **the same painted asset for landscape and portrait
/// today** — only `landscape` ships in `Assets.xcassets`. The model
/// keeps a placeholder `portrait` profile alongside `landscape` so a
/// future portrait variant can drop in without touching call sites.
private struct WorkbookPageInsets {
    /// Fraction of the rendered book height reserved for the bookmark
    /// + book top edge.
    let topFraction: CGFloat
    /// Fraction of the rendered book height reserved for the wooden
    /// bottom curve.
    let bottomFraction: CGFloat
    /// Fraction of the rendered book width reserved for the left
    /// cover rim + yellow side tabs.
    let leadingFraction: CGFloat
    /// Fraction of the rendered book width reserved for the right
    /// cover rim + yellow side tabs.
    let trailingFraction: CGFloat
    /// Floor (in points) so iPad Mini-class widths still get
    /// readable margins on the inner page area. Kept in
    /// `PaintedArtContentInsets` so workbook chrome reserves the same
    /// minimum live-text safety margin as the other painted lesson art.
    let minPadding: CGFloat

    func top(in size: CGSize) -> CGFloat {
        max(minPadding, size.height * topFraction)
    }

    func bottom(in size: CGSize) -> CGFloat {
        max(minPadding, size.height * bottomFraction)
    }

    func leading(in size: CGSize) -> CGFloat {
        max(minPadding, size.width * leadingFraction)
    }

    func trailing(in size: CGSize) -> CGFloat {
        max(minPadding, size.width * trailingFraction)
    }

    /// Calibrated to the painted `lesson_workbook_45_landscape` PNG.
    /// Values were chosen by inspecting where the cream paper area
    /// begins inside the painted wooden cover + tabs + bookmark.
    static let landscape = WorkbookPageInsets(
        topFraction:      0.13,
        bottomFraction:   0.16,
        leadingFraction:  0.10,
        trailingFraction: 0.10,
        minPadding:       PaintedArtContentInsets.workbookChromeMinimum
    )

    /// Same art, slightly tighter horizontal margins for portrait
    /// where the book is rendered narrower. Reserved for when a
    /// dedicated portrait painting ships; today both orientations use
    /// the landscape art so the shell falls through to this profile
    /// only if a portrait override is wired up later.
    static let portrait = WorkbookPageInsets(
        topFraction:      0.13,
        bottomFraction:   0.16,
        leadingFraction:  0.08,
        trailingFraction: 0.08,
        minPadding:       PaintedArtContentInsets.workbookChromeCompactMinimum
    )
}

private func hasAsset(_ name: String) -> Bool {
    UIImage(named: name) != nil
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Lesson book — sample content") {
    LessonBookReaderShell {
        VStack(spacing: 16) {
            Text("Lesson Title")
                .font(.title2.weight(.bold))
                .foregroundStyle(NovaPalette.classroomInk)
            Text("This is where the card content renders inside the book spread.")
                .font(.body)
                .foregroundStyle(NovaPalette.classroomInk.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.lg)
    }
    .padding(.horizontal, Spacing.lg)
    .padding(.vertical, Spacing.md)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(NovaPalette.classroomPaper.opacity(0.5))
}
