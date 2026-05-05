import SwiftUI

/// Progress indicator dots for flipbook card navigation.
///
/// Shows current page position with animated transitions between states.
///
/// S11-11 palette pass: completed → `sun`, current → `coral`, upcoming →
/// `ink` outline, all against `novaBackground`. The card-shaped chrome
/// was removed — dots now float on the page, letting the Flipbook read
/// as one continuous comic strip instead of three stacked cards.
public struct CardProgressDots: View {
    /// Current card index (0-based).
    let currentIndex: Int

    /// Total number of cards.
    let totalCards: Int

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    /// Dot sizes scale with Dynamic Type for accessibility
    @ScaledMetric(relativeTo: .caption) private var currentDotSize: CGFloat = 12
    @ScaledMetric(relativeTo: .caption) private var smallDotSize: CGFloat = 8
    @ScaledMetric(relativeTo: .caption) private var minTapSize: CGFloat = 44

    public init(currentIndex: Int, totalCards: Int) {
        self.currentIndex = currentIndex
        self.totalCards = totalCards
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalCards, id: \.self) { index in
                dot(for: index)
            }

            Spacer()

            Text("Page \(currentIndex + 1) of \(totalCards)")
                .font(NovaPalette.captionFont())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Page indicator")
        .accessibilityValue("Page \(currentIndex + 1) of \(totalCards)")
    }

    /// Renders one dot, dispatched on whether it's past / current / future.
    ///
    /// Pulled out of the body ForEach to keep the type checker happy and
    /// to make the three visual states read top-to-bottom.
    @ViewBuilder
    private func dot(for index: Int) -> some View {
        if index == currentIndex {
            // Current — highlighted sticker on the rail. School-red fill with
            // an ink ring so the kid can spot "you are here" at a glance.
            ZStack {
                Circle()
                    .fill(NovaPalette.classroomSchoolRed)
                Circle()
                    .strokeBorder(NovaPalette.classroomInk, lineWidth: 2)
            }
            .frame(width: currentDotSize, height: currentDotSize)
            .scaleEffect(1.0)
            .animation(
                reduceMotion
                    ? .none
                    : .spring(response: 0.3, dampingFraction: 0.7),
                value: currentIndex
            )
            .frame(minWidth: minTapSize, minHeight: minTapSize)
            .contentShape(Circle())
        } else if index < currentIndex {
            // Completed — sun sticker with a chalk check, like a teacher's
            // checked-off page on the rail.
            ZStack {
                Circle()
                    .fill(NovaPalette.classroomSun)
                Image(systemName: "checkmark")
                    .font(.system(size: smallDotSize * 0.7, weight: .heavy))
                    .foregroundStyle(NovaPalette.classroomInk)
                    .accessibilityHidden(true)
            }
            .frame(width: smallDotSize, height: smallDotSize)
            .frame(minWidth: minTapSize, minHeight: minTapSize)
            .contentShape(Circle())
        } else {
            // Upcoming — soft dashed chalk/ink ring so it reads as "still to
            // come" without pulling focus from the current sticker.
            Circle()
                .strokeBorder(
                    NovaPalette.classroomInk.opacity(0.40),
                    style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2.5])
                )
                .frame(width: smallDotSize, height: smallDotSize)
                .frame(minWidth: minTapSize, minHeight: minTapSize)
                .contentShape(Circle())
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CardProgressDots(currentIndex: 0, totalCards: 5)
        CardProgressDots(currentIndex: 2, totalCards: 5)
        CardProgressDots(currentIndex: 4, totalCards: 5)
    }
    .padding(20)
    .background(NovaPalette.novaBackground)
}
