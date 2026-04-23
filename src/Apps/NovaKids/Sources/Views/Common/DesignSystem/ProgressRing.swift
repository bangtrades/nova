import SwiftUI

/// Circular progress ring with ink-toned track and coral arc (S11-07).
///
/// `ProgressRing` is the canonical shape for "how far along" in Nova Kids —
/// badge progress on the trophy detail sheet, lesson progress on future
/// surfaces, streak progress on the parent dashboard. Having a single type
/// means every ring in the app shares the same line weight, cap style, and
/// starting angle, so the reading is consistent across screens.
///
/// ## Visual language
///
/// - **Track**: `NovaPalette.ink.opacity(0.15)` — the full circle always
///   visible at a subtle weight, so even 0% progress reads as a ring (a kid
///   should never see an empty void).
/// - **Fill**: `NovaPalette.coral` — the arc that sweeps clockwise from 12
///   o'clock. Coral is the primary action/energy color in the 3+1 palette;
///   making progress "fill in with coral" makes completion feel kinetic.
/// - **Line cap**: round — softer than butt, reads friendlier on a kids
///   surface and lets the arc tip suggest motion rather than stopping hard.
/// - **Start angle**: 12 o'clock (90° counter-clockwise from SwiftUI's
///   default 3 o'clock origin). Matches how kids read clocks.
///
/// ## Content slot
///
/// The ring takes an optional `@ViewBuilder content:` closure so callers can
/// drop a badge icon, a percentage label, or nothing into its center. The
/// content is center-aligned via the enclosing ZStack; the ring sizes to
/// its parent's frame, so the caller controls the overall dimension.
///
/// ```swift
/// ProgressRing(progress: 0.65) {
///     Image(systemName: "book.fill")
///         .font(.largeTitle)
///         .foregroundStyle(NovaPalette.ink)
/// }
/// .frame(width: 120, height: 120)
/// ```
///
/// ## Animation + reduce motion
///
/// When `progress` changes, the coral arc animates with a 0.6s ease-out
/// curve that makes the fill feel like it "catches up" rather than snaps.
/// Under `accessibilityReduceMotion`, the animation is dropped — the new
/// value appears immediately. This respects users who've opted out of
/// non-essential motion without removing the informational value.
///
/// ## Accessibility
///
/// The ring itself carries no accessibility label or value — the caller
/// supplies context via the parent view (e.g. "Badge progress: 65% of the
/// way to Voice Adventurer"). This mirrors how SF Symbols work: the shape
/// is semantic scaffolding, the surrounding view supplies meaning.
public struct ProgressRing<Content: View>: View {
    /// Progress value, clamped to 0.0...1.0 at render time so callers can
    /// pass unclamped values without worrying about overshoot.
    private let progress: Double

    /// Line width for both track and fill. 8pt is the default — comfortable
    /// on a 120pt ring, visible on a 60pt ring. Callers sizing a very small
    /// or very large ring should tune this.
    private let lineWidth: CGFloat

    /// Content placed at the ring's center. Usually a badge icon, sometimes
    /// a percentage label, sometimes empty.
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        progress: Double,
        lineWidth: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.content = content()
    }

    public var body: some View {
        let clamped = max(0, min(1, progress))

        ZStack {
            // Track — full circle at a subtle ink tint. Always drawn so the
            // ring shape reads even at 0% progress.
            Circle()
                .stroke(
                    NovaPalette.ink.opacity(0.15),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // Fill arc — coral sweep from 12 o'clock clockwise. Rotation
            // rebases the 0° origin from SwiftUI's default (3 o'clock) to
            // the top, which is how kids intuitively read "start here".
            Circle()
                .trim(from: 0, to: CGFloat(clamped))
                .stroke(
                    NovaPalette.coral,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.6),
                    value: clamped
                )

            content
        }
    }
}

/// Convenience initializer for rings that don't need a content slot.
///
/// Saves callers from writing `ProgressRing(progress: x) { EmptyView() }` at
/// the common "just draw the ring" call site.
public extension ProgressRing where Content == EmptyView {
    init(progress: Double, lineWidth: CGFloat = 8) {
        self.init(progress: progress, lineWidth: lineWidth) { EmptyView() }
    }
}

#Preview("ProgressRing — sizes + content") {
    VStack(spacing: Spacing.xl) {
        HStack(spacing: Spacing.lg) {
            ProgressRing(progress: 0.25)
                .frame(width: 60, height: 60)

            ProgressRing(progress: 0.6, lineWidth: 10) {
                Image(systemName: "book.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(NovaPalette.ink)
            }
            .frame(width: 120, height: 120)

            ProgressRing(progress: 1.0, lineWidth: 12) {
                Image(systemName: "checkmark")
                    .font(.title.weight(.heavy))
                    .foregroundStyle(NovaPalette.coral)
            }
            .frame(width: 140, height: 140)
        }

        ProgressRing(progress: 0.75) {
            VStack(spacing: Spacing.xs) {
                Text("75%")
                    .font(NovaPalette.displayFont(size: 32))
                    .foregroundStyle(NovaPalette.ink)
                Text("of the way")
                    .font(NovaPalette.captionFont())
                    .foregroundStyle(NovaPalette.ink.opacity(0.7))
            }
        }
        .frame(width: 160, height: 160)
    }
    .padding(Spacing.xl)
    .background(NovaPalette.novaBackground)
}
