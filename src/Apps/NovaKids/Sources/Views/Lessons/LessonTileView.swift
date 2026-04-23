import SwiftUI
import NovaCore

/// Individual lesson tile for the masonry grid.
///
/// Displays a lesson thumbnail, title, difficulty, description, and completion
/// status. S11-12 re-skin routes the tile through the DS visual language
/// (ink outline + coral accent stripe + page background matching `NovaCard`),
/// adds a "NEW" badge for recently published lessons, and — on iPad where a
/// pointer is available — lifts the tile on hover. Layout is unchanged so the
/// parent `MasonryGrid`'s column-width math still reads one tile size.
public struct LessonTileView: View {
    /// The lesson to display.
    let lesson: Lesson

    /// Whether the lesson is complete.
    let isComplete: Bool

    /// Callback when tapped.
    let onTap: () -> Void

    // iPad pointer interactions use `.onHover`; iPhone never fires the event.
    // Gated by `horizontalSizeClass` so the hover scale is a no-op on compact
    // width regardless of reduce-motion preference.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isHovering = false

    public init(lesson: Lesson, isComplete: Bool = false, onTap: @escaping () -> Void) {
        self.lesson = lesson
        self.isComplete = isComplete
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                thumbnail
                content
            }
            // Clip the VStack's content (thumbnail gradient fills the full
            // width, flush to the top corners) to the outer rounded
            // silhouette. Applied FIRST so the gradient doesn't leak past
            // the stroke. `.background(in:)` below then paints the warm
            // page colour behind everything in the same shape.
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(
                NovaPalette.page,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            // S11-12: accent stripe on the leading edge picks up the DS
            // `NovaCard` idiom — difficulty-coded colour lets a row of
            // tiles read as a difficulty curve at a glance (all-green
            // = easy row, etc.) without an extra text label. The 6pt
            // frame with a 20pt corner-radius clip matches NovaCard's
            // stripe technique — top/bottom leading corners curve inward;
            // trailing edge is straight because 20pt of radius can't fit
            // in 6pt of width.
            .overlay(alignment: .leading) {
                accentColor
                    .frame(width: 6)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .allowsHitTesting(false)
            }
            // 2pt ink outline wraps the stripe — reads as an inked
            // illustration against the warm page background, not a
            // floating chip. Applied as a final overlay so the clipShape
            // above doesn't eat into the stroke width.
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(NovaPalette.ink, lineWidth: 2)
            }
            // S11-12: NEW badge top-leading, completion checkmark top-
            // trailing. Two separate overlays so the two signals land in
            // opposite corners and never collide regardless of tile width.
            .overlay(alignment: .topLeading) {
                if isNew {
                    newBadge.padding(Spacing.sm)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isComplete {
                    completionBadge.padding(Spacing.sm)
                }
            }
            .shadow(color: NovaPalette.ink.opacity(0.12), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(shouldLift ? 1.02 : 1.0)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            // `.onHover` fires on iPad + Mac; iPhone touch never triggers it,
            // so the scale math is free on phones.
            isHovering = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Double tap to open this lesson")
    }

    /// iPad (regular width class) + pointer-hover, gated so iPhone never
    /// wastes a layout pass recomputing `scaleEffect`.
    private var shouldLift: Bool {
        isHovering && horizontalSizeClass == .regular && !reduceMotion
    }

    /// Difficulty-driven accent — 1/2/3 maps to the category rainbow's easy,
    /// medium, challenging stops so a row of tiles reads as a difficulty curve.
    private var accentColor: Color {
        switch lesson.difficulty {
        case 1: return NovaPalette.novaGreen
        case 2: return NovaPalette.novaOrange
        case 3: return NovaPalette.novaPurple
        default: return NovaPalette.coral
        }
    }

    /// "New" = published within the last seven days. Conservative window so
    /// the badge means something — if every tile is NEW, none of them are.
    private var isNew: Bool {
        guard let publishedAt = lesson.publishedAt else { return false }
        let sevenDays: TimeInterval = 7 * 24 * 60 * 60
        return Date().timeIntervalSince(publishedAt) < sevenDays
    }

    private var accessibilityLabel: String {
        isNew ? "New lesson: \(lesson.title)" : lesson.title
    }

    private var accessibilityValue: String {
        "\(lesson.difficulty) stars\(isComplete ? ", completed" : "")"
    }

    // MARK: - Subviews

    /// Gradient thumbnail — preserved shape from pre-S11-12 so the masonry
    /// rhythm doesn't change. Fills the top 140pt flush to the card edge;
    /// the ink stroke on the outer overlay wraps it.
    private var thumbnail: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    accentColor.opacity(0.5),
                    NovaPalette.sun.opacity(0.35),
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: Spacing.xs) {
                Image(systemName: "book.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)

                Text("Lesson")
                    .font(NovaPalette.captionFont())
                    .foregroundStyle(.white.opacity(0.9))
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 140)
    }

    /// Title + difficulty stars + description block.
    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(lesson.title)
                .font(NovaPalette.smallHeadingFont())
                .foregroundStyle(NovaPalette.ink)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Difficulty stars — filled stars in sun yellow, empty in ink-30%
            // for the DS-era palette (replaces the earlier novaYellow/ink.opacity
            // combination which read fine but skipped the 3+1 palette rule).
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < lesson.difficulty ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(
                            index < lesson.difficulty
                                ? NovaPalette.sun
                                : NovaPalette.ink.opacity(0.3)
                        )
                        .accessibilityHidden(true)
                }
                Spacer()
            }
            .accessibilityHidden(true)

            Text(lesson.description)
                .font(NovaPalette.captionFont())
                .foregroundStyle(NovaPalette.ink.opacity(0.7))
                .lineLimit(2)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Completion checkmark — coral-filled with ink stroke, matches the
    /// "celebrate on the page" DS direction.
    private var completionBadge: some View {
        ZStack {
            Circle()
                .fill(NovaPalette.coral)
                .overlay(Circle().stroke(NovaPalette.ink, lineWidth: 2))
                .frame(width: 36, height: 36)

            Image(systemName: "checkmark")
                .font(.body.weight(.bold))
                .foregroundStyle(NovaPalette.page)
                .accessibilityHidden(true)
        }
    }

    /// NEW pill — sun fill + ink stroke + Bangers caps. Ink text on sun is a
    /// WCAG-safe pairing (≈ 10:1 ratio) and the shape is a badge, not a
    /// button, so it reads as "notice me" without inviting a tap.
    private var newBadge: some View {
        Text("NEW")
            .font(NovaPalette.displayFont(size: 14))
            .foregroundStyle(NovaPalette.ink)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule(style: .continuous)
                    .fill(NovaPalette.sun)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(NovaPalette.ink, lineWidth: 2)
            )
            .accessibilityHidden(true) // Label already carries "New lesson:" prefix
    }
}

#Preview {
    let recent = Lesson(
        id: UUID(),
        pathId: UUID(),
        userId: UUID(),
        title: "What Makes AI Smart?",
        description: "Learn how AI learns from data",
        thumbnailURL: nil,
        difficulty: 2,
        sourceURL: nil,
        aiAnalysis: nil,
        status: .published,
        sortOrder: 1,
        createdAt: Date(),
        publishedAt: Date(), // fresh — badge should show
        cards: []
    )

    let older = Lesson(
        id: UUID(),
        pathId: UUID(),
        userId: UUID(),
        title: "Neural Networks 101",
        description: "How neurons learn to see",
        thumbnailURL: nil,
        difficulty: 3,
        sourceURL: nil,
        aiAnalysis: nil,
        status: .published,
        sortOrder: 2,
        createdAt: Date(),
        publishedAt: Date(timeIntervalSinceNow: -30 * 24 * 60 * 60), // 30 days — no badge
        cards: []
    )

    VStack(spacing: Spacing.md) {
        LessonTileView(lesson: recent, isComplete: false) { }
        LessonTileView(lesson: older, isComplete: true) { }
    }
    .padding(Spacing.lg)
    .background(NovaPalette.novaBackground)
}
