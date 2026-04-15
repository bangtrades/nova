import SwiftUI

/// Progress indicator dots for flipbook card navigation.
///
/// Shows current page position with animated transitions between states.
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
                if index == currentIndex {
                    // Current page — large filled circle
                    Circle()
                        .fill(NovaPalette.novaOrange)
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
                    // Past pages — small filled circles
                    Circle()
                        .fill(NovaPalette.novaBlue)
                        .frame(width: smallDotSize, height: smallDotSize)
                        .frame(minWidth: minTapSize, minHeight: minTapSize)
                        .contentShape(Circle())
                } else {
                    // Future pages — small empty circles
                    Circle()
                        .stroke(NovaPalette.novaBlue, lineWidth: 1.5)
                        .frame(width: smallDotSize, height: smallDotSize)
                        .frame(minWidth: minTapSize, minHeight: minTapSize)
                        .contentShape(Circle())
                }
            }

            Spacer()

            Text("Page \(currentIndex + 1) of \(totalCards)")
                .font(NovaPalette.captionFont())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(NovaPalette.novaCardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Page indicator")
        .accessibilityValue("Page \(currentIndex + 1) of \(totalCards)")
    }
}

#Preview {
    VStack(spacing: 20) {
        CardProgressDots(currentIndex: 0, totalCards: 5)
        CardProgressDots(currentIndex: 2, totalCards: 5)
        CardProgressDots(currentIndex: 4, totalCards: 5)
    }
    .padding(20)
}
