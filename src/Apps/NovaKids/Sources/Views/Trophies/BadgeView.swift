import SwiftUI
import NovaCore

/// Compact badge tile shown in the trophy room grid (S11-07 refresh).
///
/// `BadgeView` is the small footprint — rendered in a 3-column grid on the
/// main trophy screen. The hero detail view lives in `BadgeDetailSheet`
/// (inside `TrophyRoomView`), which trades tile density for large visuals
/// and the `BadgeUnlockBurst` celebration.
///
/// ## Visual language (S11-07)
///
/// - **Badge circle**: sun → coral gradient when earned, ink-tone gradient
///   when locked. Wrapped in a 2pt ink stroke so the badge feels like a
///   comic-book panel element, not a flat iOS icon.
/// - **Badge name**: Bangers display face so the title carries the
///   comic-book energy of `NovaCard` headers and quiz questions.
/// - **Progress (locked)**: slim coral capsule bar beneath the title, with
///   an ink-tint track. Linear bar instead of a ring keeps the tile
///   visually tight — the hero sheet uses `ProgressRing` for the
///   expressive version.
/// - **Earned entrance**: spring scale-in on first appear (skipped under
///   `accessibilityReduceMotion`). Replaces the previous single-star
///   "sparkle" which was too subtle to register as celebration.
///
/// ## Why no `NovaCard` wrapper
///
/// `NovaCard` is great for surfaces where a leading accent stripe carries
/// category identity, but on a 3-column badge grid the stripe adds visual
/// noise that competes with the badge circle itself. This tile uses a
/// simpler chrome — page fill, ink stroke, 16pt rounded — that mirrors
/// `NovaCard`'s language without repeating the stripe.
public struct BadgeView: View {
    let earned: Bool
    let badge: Badge
    let progress: Float
    let earnedDate: Date?

    /// Drives the earned entrance animation — starts pre-bounce and springs
    /// to rest on appear. Private to the tile so its lifecycle is tied to
    /// the individual cell, not the grid.
    @State private var earnedScale: CGFloat = 0.85
    @State private var hasAppeared = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        earned: Bool,
        badge: Badge,
        progress: Float = 0,
        earnedDate: Date? = nil
    ) {
        self.earned = earned
        self.badge = badge
        self.progress = progress
        self.earnedDate = earnedDate
    }

    public var body: some View {
        VStack(spacing: Spacing.sm) {
            badgeCircle
                .frame(width: 88, height: 88)
                .scaleEffect(earnedScale)

            Text(badge.title)
                .font(NovaPalette.displayFont(size: 18))
                .foregroundStyle(NovaPalette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                // `minHeight` (not `height`) so the title can grow under
                // large Dynamic Type without clipping Bangers ascenders.
                // The grid equalizes tile heights to the tallest peer, so
                // an overflowing title pushes the whole row, not just
                // this cell.
                .frame(minHeight: 44, alignment: .top)

            statusRow
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(
            NovaPalette.page,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NovaPalette.ink, lineWidth: 2)
        }
        .opacity(earned ? 1.0 : 0.85)
        .onAppear(perform: animateEntrance)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(badge.title)
        .accessibilityValue(accessibilityValueText)
    }

    // MARK: - Subviews

    /// The circular badge disc — gradient fill, ink stroke, icon centered.
    private var badgeCircle: some View {
        ZStack {
            Circle()
                .fill(fillGradient)

            // Ink outline — 2pt matches `NovaCard` stroke weight so the
            // badge feels part of the same comic-book world.
            Circle()
                .stroke(NovaPalette.ink, lineWidth: 2)

            // Sun glow behind the icon for earned badges — radial bleed
            // suggests the disc is warm/lit, not just a flat fill.
            if earned {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NovaPalette.sun.opacity(0.45), .clear],
                            center: .center,
                            startRadius: 8,
                            endRadius: 44
                        )
                    )
                    .blur(radius: 6)
                    .allowsHitTesting(false)
            }

            // Icon — ink on earned discs reads as "inked panel symbol"; on
            // locked discs it sits at 30% ink for a faded, unattainable feel.
            Image(systemName: badge.icon)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(earned ? NovaPalette.ink : NovaPalette.ink.opacity(0.3))

            // Lock indicator for locked badges — small padlock tucked to
            // the bottom-trailing so it doesn't cover the symbol.
            if !earned {
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NovaPalette.page)
                    .padding(6)
                    .background(NovaPalette.ink, in: Circle())
                    .offset(x: 26, y: 26)
            }
        }
    }

    /// Status row beneath the name — earned date stamp OR locked progress bar.
    @ViewBuilder
    private var statusRow: some View {
        if earned {
            Text(earnedDate.map(formatDate) ?? "Earned!")
                .font(NovaPalette.captionFont().weight(.semibold))
                .foregroundStyle(NovaPalette.coral)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        } else {
            VStack(spacing: Spacing.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(NovaPalette.ink.opacity(0.15))

                        Capsule()
                            .fill(NovaPalette.coral)
                            .frame(width: max(0, geo.size.width * CGFloat(progress)))
                    }
                }
                .frame(height: 6)

                Text("\(Int(progress * 100))%")
                    .font(NovaPalette.captionFont())
                    .foregroundStyle(NovaPalette.ink.opacity(0.7))
            }
        }
    }

    // MARK: - Helpers

    /// Gradient shown in the badge disc. Earned uses the celebration duo
    /// (sun → coral); locked uses an ink-tone descent so the disc still
    /// reads as a disc but doesn't compete with earned neighbors.
    private var fillGradient: LinearGradient {
        if earned {
            return LinearGradient(
                colors: [NovaPalette.sun, NovaPalette.coral],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [NovaPalette.ink.opacity(0.22), NovaPalette.ink.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// VoiceOver value string. Merges earned state + progress or earned
    /// date into a single spoken phrase.
    private var accessibilityValueText: String {
        if earned {
            if let date = earnedDate {
                return "Earned on \(formatDate(date))"
            }
            return "Earned"
        }
        return "Locked — \(Int(progress * 100)) percent progress"
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    /// Earned entrance — spring bounce on first render, skipped under
    /// reduce motion or for locked badges (nothing to celebrate).
    private func animateEntrance() {
        guard !hasAppeared else { return }
        hasAppeared = true

        guard earned, !reduceMotion else {
            earnedScale = 1.0
            return
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
            earnedScale = 1.0
        }
    }
}

#Preview {
    let sample: [(Bool, String, String, Float, Date?)] = [
        (true,  "First Lesson",       "book.circle.fill",       1.0, Date().addingTimeInterval(-86_400 * 3)),
        (false, "Voice Adventurer",   "mic.circle.fill",        0.6, nil),
        (true,  "3-Day Streak",       "flame.circle.fill",      1.0, Date().addingTimeInterval(-86_400)),
        (false, "AI Genius",          "sparkles",               0.4, nil),
    ]

    return LazyVGrid(
        columns: [
            GridItem(.flexible(), spacing: Spacing.md),
            GridItem(.flexible(), spacing: Spacing.md),
        ],
        spacing: Spacing.md
    ) {
        ForEach(sample, id: \.1) { item in
            BadgeView(
                earned: item.0,
                badge: Badge(
                    id: UUID(),
                    title: item.1,
                    description: "Sample description.",
                    icon: item.2,
                    criteria: BadgeCriteria(type: .lessonsCompleted, count: 1)
                ),
                progress: item.3,
                earnedDate: item.4
            )
        }
    }
    .padding(Spacing.lg)
    .background(NovaPalette.novaBackground)
}
