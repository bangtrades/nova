import SwiftUI

/// Loading skeleton view for progressive content display.
///
/// Renders as a row of classroom paper-page placeholders with a soft
/// chalk-dust shimmer sweeping across them, so a kid (or parent) sees
/// "the workbook is loading" rather than a generic dashboard skeleton.
/// All visuals pull from `NovaPalette.classroom*` tokens; the shimmer
/// uses a low-opacity classroom-paper sweep so dark mode and light
/// mode both read correctly without a hard-coded white overlay.
public struct LoadingSkeletonView: View {
    /// Number of skeleton items to display.
    let itemCount: Int

    /// Whether to show as a masonry grid (true) or vertical list (false).
    let isGrid: Bool

    public init(itemCount: Int = 6, isGrid: Bool = true) {
        self.itemCount = itemCount
        self.isGrid = isGrid
    }

    public var body: some View {
        if isGrid {
            VStack(spacing: Spacing.sm) {
                ForEach(0..<(itemCount / 2), id: \.self) { _ in
                    HStack(spacing: Spacing.sm) {
                        SkeletonBlock(role: .heroPaper)
                            .frame(height: 200)

                        SkeletonBlock(role: .heroPaper)
                            .frame(height: 240)
                    }
                }
            }
            .padding(Spacing.lg)
        } else {
            VStack(spacing: Spacing.md) {
                ForEach(0..<itemCount, id: \.self) { _ in
                    SkeletonBlock(role: .listRow)
                        .frame(height: 100)
                }
            }
            .padding(Spacing.lg)
        }
    }
}

/// Single skeleton block with a chalk-dust shimmer.
///
/// Each block is a paper-tinted rounded rectangle with an ink stroke
/// and a soft drop shadow — the same vocabulary used by the rest of
/// the workbook chrome. The shimmer is a chalk-dust gradient that
/// sweeps left-to-right at a calm tempo. Reduce-motion gates the
/// shimmer entirely; the static paper rectangle still reads as
/// "content loading".
private struct SkeletonBlock: View {
    enum Role {
        /// Larger card-shaped placeholder for grid surfaces.
        case heroPaper
        /// Slimmer list-row placeholder.
        case listRow
    }

    let role: Role

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(NovaPalette.classroomPaper.opacity(0.92))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.18), lineWidth: 1.5)
            }
            .overlay {
                if reduceMotion == false {
                    chalkDustShimmer
                        .clipShape(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        )
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .shadow(color: NovaPalette.classroomInk.opacity(0.10), radius: 4, x: 0, y: 2)
            .accessibilityElement()
            .accessibilityLabel("Loading")
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var cornerRadius: CGFloat {
        switch role {
        case .heroPaper: return 18
        case .listRow:   return 14
        }
    }

    /// Soft chalk-dust sweep that runs left-to-right behind the paper
    /// rectangle. Driven by `TimelineView(.animation)` so the shimmer
    /// renders consistently without leaning on `@State` toggles.
    private var chalkDustShimmer: some View {
        TimelineView(.animation) { context in
            let phase = (context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 2.4)) / 2.4
            let unit = CGFloat(phase) * 2 - 0.5 // -0.5 ... 1.5

            GeometryReader { proxy in
                LinearGradient(
                    colors: [
                        NovaPalette.classroomChalkDust.opacity(0.0),
                        NovaPalette.classroomChalkDust.opacity(0.28),
                        NovaPalette.classroomChalkDust.opacity(0.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: proxy.size.width * 0.6)
                .offset(x: unit * proxy.size.width)
            }
        }
    }
}

#Preview("Grid") {
    LoadingSkeletonView()
        .background(NovaPalette.classroomChalkboard.opacity(0.18))
}

#Preview("List") {
    LoadingSkeletonView(itemCount: 4, isGrid: false)
        .background(NovaPalette.classroomChalkboard.opacity(0.18))
}
