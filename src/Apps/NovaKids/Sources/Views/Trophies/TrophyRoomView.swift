import SwiftUI
import NovaCore

/// Trophy room — earned and locked badges, streak counter, top-line stats
/// (S11-07 design system pass).
///
/// The screen is a single vertical scroll with three sections:
///
/// 1. **Header card** (`NovaCard`, coral accent) — streak flame on the
///    leading side, "Badges Earned" count on the trailing side. Bangers
///    display type for both numerics so the moment of arrival lands with
///    the comic-book energy the rest of the app carries.
/// 2. **Stat row** — three compact `NovaCard` tiles using the `ink / sun /
///    coral` trio instead of the old blue/yellow/green rainbow. Each tile
///    carries a single icon + value + label, so the user can scan their
///    progress at a glance.
/// 3. **Achievements grid** — a 3-column `LazyVGrid` of `BadgeView` tiles.
///    Tapping a tile presents `BadgeDetailSheet` with the hero view and
///    unlock celebration.
///
/// ## Why every panel is `NovaCard`
///
/// S11-03 established `NovaCard` as the one card container in the system.
/// Before this pass, the trophy screen hand-rolled its own panels with
/// `.background(NovaPalette.novaCardBackground).cornerRadius(12).shadow(...)`
/// — functional, but divergent. Routing every panel through `NovaCard` means
/// a future tweak to stroke weight, shadow depth, or corner radius only
/// happens in one file and propagates here for free.
public struct TrophyRoomView: View {
    @StateObject private var viewModel = TrophyRoomViewModel()
    @EnvironmentObject private var apiRouter: APIRouter
    @EnvironmentObject private var appState: KidsAppState
    @EnvironmentObject private var completionStore: LessonCompletionStore
    @State private var selectedBadge: TrophyRoomViewModel.BadgeDisplayItem?

    // S12-01: iPad-vs-iPhone density. `.regular` gets 5 columns so the
    // rainbow badge wall fills the landscape; `.compact` keeps the 3-col
    // grid the tile size was drawn for.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 5 : 3
        return Array(
            repeating: GridItem(.flexible(), spacing: Spacing.md),
            count: count
        )
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                NovaPalette.novaBackground
                    .ignoresSafeArea()

                ScrollView(.vertical) {
                    VStack(spacing: Spacing.lg) {
                        // S11-19: error banner matches Home / Lessons /
                        // Dashy language — page fill + ink stroke + coral
                        // icon + .novaSecondary() "Try Again". Shows above
                        // the skeleton so a failed retry doesn't obscure
                        // the last-known content.
                        if let error = viewModel.loadError {
                            errorBanner(message: error.errorDescription ?? "Something went wrong")
                        }

                        if viewModel.isLoading {
                            // S11-14: surface the shared skeleton during
                            // pull-to-refresh so the trophy grid doesn't
                            // flash empty. Grid mode matches the 3-col
                            // achievements section and reads as "badges
                            // are loading" without inventing a new shape.
                            LoadingSkeletonView(itemCount: 6, isGrid: true)
                        } else {
                            headerCard
                            // S13: Your Trophies — completed-lesson
                            // memorabilia keyed on the active child.
                            // Each tile uses the lesson's hero image as
                            // the trophy art so the trophy is visually
                            // bound to the lesson the kid completed.
                            // Renders only when there's at least one
                            // trophy so first-time users don't see an
                            // empty section above their unearned-badge
                            // grid.
                            yourTrophiesSection
                            statRow
                            achievementsSection
                        }
                    }
                    .padding(Spacing.lg)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await viewModel.refreshBadges()
                }
            }
            .novaNavigationStyle(title: "Trophies")
            .sheet(item: $selectedBadge) { badge in
                BadgeDetailSheet(item: badge)
            }
            // S11-19 wire-up: attach router + child id, then kick off first
            // fetch. `attach` is fine to re-run on tab re-select.
            .task {
                viewModel.attach(apiRouter: apiRouter, childId: appState.currentChild?.id)
                await viewModel.loadBadges()
            }
        }
    }

    /// S13: Trophies earned from completing lessons. Each tile shows
    /// the lesson's hero image inside a gold ring. Empty state hidden —
    /// section only renders when at least one trophy exists.
    @ViewBuilder
    private var yourTrophiesSection: some View {
        let trophies = completionStore.trophies(for: appState.currentChild?.id)
        if !trophies.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: 8) {
                    Text("Your Trophies")
                        .font(NovaPalette.headingFont(size: 22))
                        .foregroundStyle(NovaPalette.ink)
                    Text("(\(trophies.count))")
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(NovaPalette.ink.opacity(0.5))
                    Spacer()
                }
                LazyVGrid(columns: columns, spacing: Spacing.md) {
                    ForEach(trophies) { trophy in
                        lessonTrophyTile(trophy)
                    }
                }
            }
        }
    }

    /// One trophy tile. Hero image + trophy name caption. Square
    /// aspect ratio matches the achievements grid below for visual
    /// rhythm.
    @ViewBuilder
    private func lessonTrophyTile(_ trophy: LessonCompletionStore.TrophyRecord) -> some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(NovaPalette.sun, lineWidth: 4)
                    .shadow(color: NovaPalette.sun.opacity(0.4), radius: 8)

                Group {
                    if let urlString = trophy.lessonHeroImageURL,
                       let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .empty, .failure:
                                trophyPlaceholder
                            @unknown default:
                                trophyPlaceholder
                            }
                        }
                    } else {
                        trophyPlaceholder
                    }
                }
                .clipShape(Circle())
                .padding(6) // Inset so image stays inside the gold ring
            }
            .aspectRatio(1, contentMode: .fit)

            Text(trophy.trophyName)
                .font(NovaPalette.captionFont())
                .foregroundStyle(NovaPalette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(trophy.trophyName)
        .accessibilityValue("Earned \(trophy.completedAt.formatted(date: .abbreviated, time: .omitted))")
    }

    private var trophyPlaceholder: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    NovaPalette.coral.opacity(0.6),
                    NovaPalette.sun.opacity(0.6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "trophy.fill")
                .font(.title)
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func errorBanner(message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(NovaPalette.coral)
            Text(message)
                .font(NovaPalette.captionFont())
                .foregroundStyle(NovaPalette.ink)
                .lineLimit(2)
            Spacer()
            Button("Try Again") {
                Task { await viewModel.refreshBadges() }
            }
            .novaSecondary()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NovaPalette.page)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(NovaPalette.ink, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error loading trophies: \(message)")
    }

    // MARK: - Sections

    /// Streak + badges-earned header. Coral accent on the card nudges the
    /// eye to the trophy-room-identity moment without shouting.
    private var headerCard: some View {
        NovaCard {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("My Trophies")
                        .font(NovaPalette.displayFont(size: 28))
                        .foregroundStyle(NovaPalette.ink)

                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(NovaPalette.coral)
                        Text("\(viewModel.currentStreak) day streak")
                            .font(NovaPalette.bodyFont().weight(.semibold))
                            .foregroundStyle(NovaPalette.ink.opacity(0.75))
                    }
                }

                Spacer(minLength: Spacing.md)

                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text("\(earnedCount)")
                        .font(NovaPalette.displayFont(size: 40))
                        .foregroundStyle(NovaPalette.sun)
                        .shadow(color: NovaPalette.ink, radius: 0, x:  1, y:  0)
                        .shadow(color: NovaPalette.ink, radius: 0, x: -1, y:  0)
                        .shadow(color: NovaPalette.ink, radius: 0, x:  0, y:  1)
                        .shadow(color: NovaPalette.ink, radius: 0, x:  0, y: -1)

                    Text("badges earned")
                        .font(NovaPalette.captionFont())
                        .foregroundStyle(NovaPalette.ink.opacity(0.7))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(earnedCount) badges earned")
            }
        }
    }

    /// Three-across stat row — lessons completed, level, badges completion
    /// fraction. Trio uses ink / sun / coral to match the 3+1 palette.
    private var statRow: some View {
        HStack(spacing: Spacing.md) {
            StatTile(
                icon: "book.fill",
                label: "Lessons",
                value: "\(viewModel.totalLessonsCompleted)",
                tint: NovaPalette.ink
            )
            StatTile(
                icon: "star.fill",
                label: "Level",
                value: "Explorer",
                tint: NovaPalette.sun
            )
            StatTile(
                icon: "checkmark.seal.fill",
                label: "Complete",
                value: "\(earnedCount)/\(viewModel.badges.count)",
                tint: NovaPalette.coral
            )
        }
    }

    /// Achievements grid — or empty state if the learner hasn't started.
    @ViewBuilder
    private var achievementsSection: some View {
        if viewModel.badges.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Achievements")
                    .font(NovaPalette.displayFont(size: 24))
                    .foregroundStyle(NovaPalette.ink)

                LazyVGrid(columns: columns, spacing: Spacing.md) {
                    ForEach(viewModel.badges) { item in
                        Button {
                            NovaHaptics.tap()
                            selectedBadge = item
                        } label: {
                            BadgeView(
                                earned: item.isEarned,
                                badge: item.badge,
                                progress: item.progress,
                                earnedDate: item.earnedDate
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Empty-state pane shown when the learner has zero badges in view (new
    /// account, pre-first-lesson). Wraps in a `NovaCard` so the empty state
    /// still feels like a furnished room, not a blank screen.
    private var emptyState: some View {
        NovaCard(accent: NovaPalette.sun) {
            VStack(spacing: Spacing.md) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(NovaPalette.sun)
                    .shadow(color: NovaPalette.ink.opacity(0.15), radius: 4, x: 0, y: 2)

                Text("No Badges Yet")
                    .font(NovaPalette.displayFont(size: 22))
                    .foregroundStyle(NovaPalette.ink)

                Text("Complete lessons to earn your first badge!")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(NovaPalette.ink.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.lg)
        }
    }

    // MARK: - Helpers

    private var earnedCount: Int {
        viewModel.badges.filter(\.isEarned).count
    }
}

// MARK: - StatTile

/// Compact stat tile — icon + value + label, wrapped in a `NovaCard` whose
/// accent matches the tile's tint. Exposed at file scope so both the
/// trophy screen and future dashboards can reuse the same shape.
private struct StatTile: View {
    let icon: String
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        NovaCard(accent: tint) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)

                Text(value)
                    .font(NovaPalette.displayFont(size: 22))
                    .foregroundStyle(NovaPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(label)
                    .font(NovaPalette.captionFont())
                    .foregroundStyle(NovaPalette.ink.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Badge Detail Sheet

/// Presented when a learner taps a badge in the grid.
///
/// Composition (top → bottom):
///
/// - **Hero block** (`NovaCard`, sun accent) — `ProgressRing` wrapping the
///   badge disc, then Bangers badge title, then description, then the
///   earned-date stamp or progress readout.
/// - **Criteria block** (`NovaCard`, coral accent) — "How to earn" header
///   plus the single criterion line derived from `BadgeCriteria`.
/// - **Close button** — `NovaSecondaryButtonStyle` at the bottom safe area,
///   carrying the same tap language as every other secondary action in the
///   app.
///
/// **Unlock celebration.** When the sheet is opened for an earned badge,
/// `BadgeUnlockBurst` overlays the screen with a comic-book "UNLOCKED!"
/// word paired with `NovaHaptics.success()`. The burst auto-dismisses after
/// ~1.4s; it does not block scrolling or interaction. Under reduce motion
/// the burst degrades to a plain fade.
private struct BadgeDetailSheet: View {
    let item: TrophyRoomViewModel.BadgeDisplayItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showUnlockBurst = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                NovaPalette.novaBackground
                    .ignoresSafeArea()

                ScrollView(.vertical) {
                    VStack(spacing: Spacing.lg) {
                        heroBlock
                        criteriaBlock
                    }
                    .padding(Spacing.lg)
                    .padding(.bottom, Spacing.xxl) // Leave room above the Close button
                }
                .scrollIndicators(.hidden)

                // Unlock burst sits above the hero block and doesn't take hits.
                BadgeUnlockBurst(isActive: $showUnlockBurst)
                    .padding(.top, Spacing.xl)
                    .allowsHitTesting(false)
            }
            .safeAreaInset(edge: .bottom) {
                // Fade-to-page gradient sits BEHIND the button inside the
                // inset's own frame. A previous iteration put the gradient
                // as `.background(... .ignoresSafeArea())` on the button
                // itself — the inner ignoresSafeArea was clipped to the
                // button's footprint, so the fade never reached the scroll
                // content above. ZStack inside the inset container is the
                // reliable composition for "button on a fade".
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: [
                            NovaPalette.novaBackground.opacity(0),
                            NovaPalette.novaBackground
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 72)
                    .allowsHitTesting(false)

                    Button("Close") {
                        dismiss()
                    }
                    .novaSecondary()
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.sm)
                }
            }
            .novaNavigationStyle(title: "Badge Details")
            .onAppear {
                if item.isEarned {
                    NovaHaptics.success()
                    showUnlockBurst = true
                }
            }
        }
    }

    // MARK: - Sheet sections

    /// Hero block — ProgressRing wrapping the large badge disc, then the
    /// badge title/description, then earned-date or progress readout.
    private var heroBlock: some View {
        NovaCard(accent: NovaPalette.sun) {
            VStack(spacing: Spacing.md) {
                ZStack {
                    ProgressRing(
                        progress: item.isEarned ? 1.0 : Double(item.progress),
                        lineWidth: 10
                    )
                    .frame(width: 180, height: 180)

                    heroBadgeDisc
                        .frame(width: 140, height: 140)
                }
                .padding(.top, Spacing.sm)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    item.isEarned
                        ? "Badge earned"
                        : "Badge progress: \(Int(item.progress * 100)) percent"
                )

                Text(item.badge.title)
                    .font(NovaPalette.displayFont(size: 34))
                    .foregroundStyle(NovaPalette.ink)
                    .multilineTextAlignment(.center)

                Text(item.badge.description)
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(NovaPalette.ink.opacity(0.8))
                    .multilineTextAlignment(.center)

                earnedOrProgressLine
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// The big badge disc shown inside the progress ring. Same visual
    /// language as the grid tile's disc — sun → coral gradient for earned,
    /// ink descent for locked — just scaled up.
    private var heroBadgeDisc: some View {
        ZStack {
            Circle()
                .fill(
                    item.isEarned
                        ? LinearGradient(
                            colors: [NovaPalette.sun, NovaPalette.coral],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [NovaPalette.ink.opacity(0.22), NovaPalette.ink.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )

            if item.isEarned {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [NovaPalette.sun.opacity(0.5), .clear],
                            center: .center,
                            startRadius: 12,
                            endRadius: 70
                        )
                    )
                    .blur(radius: 10)
                    .allowsHitTesting(false)
            }

            Circle()
                .stroke(NovaPalette.ink, lineWidth: 2)

            Image(systemName: item.badge.icon)
                .font(.system(size: 60, weight: .semibold))
                .foregroundStyle(
                    item.isEarned
                        ? NovaPalette.ink
                        : NovaPalette.ink.opacity(0.35)
                )
        }
    }

    /// Status line beneath the hero — either the earned date with calendar
    /// icon, or a progress line + criterion target.
    @ViewBuilder
    private var earnedOrProgressLine: some View {
        if item.isEarned, let earnedDate = item.earnedDate {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "calendar")
                    .foregroundStyle(NovaPalette.coral)
                Text("Earned \(formatDate(earnedDate))")
                    .font(NovaPalette.bodyFont().weight(.semibold))
                    .foregroundStyle(NovaPalette.ink)
            }
        } else if item.isEarned {
            Text("Earned!")
                .font(NovaPalette.bodyFont().weight(.semibold))
                .foregroundStyle(NovaPalette.coral)
        } else {
            Text("\(Int(item.progress * 100))% on the way")
                .font(NovaPalette.bodyFont().weight(.semibold))
                .foregroundStyle(NovaPalette.ink.opacity(0.8))
        }
    }

    /// Criteria block — how to earn the badge, plus current/target count.
    private var criteriaBlock: some View {
        NovaCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("How to earn")
                    .font(NovaPalette.displayFont(size: 20))
                    .foregroundStyle(NovaPalette.ink)

                HStack(spacing: Spacing.sm) {
                    Image(systemName: item.isEarned ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.isEarned ? NovaPalette.coral : NovaPalette.ink.opacity(0.4))

                    Text(criteriaDescription)
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(NovaPalette.ink)
                }

                if !item.isEarned {
                    Divider()
                        .background(NovaPalette.ink.opacity(0.15))

                    HStack {
                        Text("Progress")
                            .font(NovaPalette.captionFont())
                            .foregroundStyle(NovaPalette.ink.opacity(0.7))
                        Spacer()
                        Text("\(currentCount) of \(item.badge.criteria.count)")
                            .font(NovaPalette.bodyFont().weight(.semibold))
                            .foregroundStyle(NovaPalette.ink)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var criteriaDescription: String {
        let count = item.badge.criteria.count
        switch item.badge.criteria.type {
        case .lessonsCompleted:    return "Complete \(count) lesson\(count == 1 ? "" : "s")"
        case .experimentsCompleted: return "Complete \(count) experiment\(count == 1 ? "" : "s")"
        case .daysStreak:          return "Learn for \(count) day\(count == 1 ? "" : "s") in a row"
        case .voiceInteractions:   return "Record \(count) voice response\(count == 1 ? "" : "s")"
        case .pathCompleted:       return "Finish \(count) learning path\(count == 1 ? "" : "s")"
        }
    }

    /// Best-effort current count — we don't yet track per-criterion counts
    /// in the VM, so we derive a rough estimate from the progress fraction.
    /// Shown only for locked badges; the hero view's ProgressRing carries
    /// the canonical progress visualization.
    private var currentCount: Int {
        Int((Float(item.badge.criteria.count) * item.progress).rounded())
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    TrophyRoomView()
}
