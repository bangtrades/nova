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
                trophyRoomBackground
                    .ignoresSafeArea()

                ScrollView(.vertical) {
                    VStack(spacing: Spacing.lg) {
                        // S11-19: error banner matches Home / Lessons /
                        // Dashy language — page fill + ink stroke + coral
                        // icon + .novaSecondary() "Try Again". Shows above
                        // the skeleton so a failed retry doesn't obscure
                        // the last-known content.
                        if let error = viewModel.loadError {
                            ClassroomErrorBanner(
                                message: error.errorDescription ?? "Something went wrong",
                                context: "trophies"
                            ) { Task { await viewModel.refreshBadges() } }
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
            // S14-VF-02 + V2-S4-F2: kid hears "Look at all your
            // trophies!" when there's something on the shelf, and the
            // why-it's-empty line ("Finish a lesson to earn your first
            // one") when there isn't. Keyed on the local completion
            // store, so the answer is available synchronously on
            // appear — no async badge fetch to race.
            .narrate(
                completionStore.trophies(for: appState.currentChild?.id).isEmpty
                    ? "trophyRoomEmpty"
                    : "trophyRoom"
            )
        }
    }

    /// S13: Trophies earned from completing lessons, restyled in S-classroom
    /// as a wooden shelf with paper-strap label. Each tile is a sticker
    /// inside a sun ring so the row reads like classroom shelf cubbies.
    /// Empty state hidden — section only renders when at least one trophy
    /// exists.
    @ViewBuilder
    private var yourTrophiesSection: some View {
        let trophies = completionStore.trophies(for: appState.currentChild?.id)
        if !trophies.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                sectionLabel(
                    text: "Your Trophies",
                    icon: "rosette",
                    accent: NovaPalette.classroomSun,
                    countSuffix: "(\(trophies.count))"
                )
                shelfPanel {
                    LazyVGrid(columns: columns, spacing: Spacing.md) {
                        ForEach(trophies) { trophy in
                            lessonTrophyTile(trophy)
                        }
                    }
                }
            }
        }
    }

    /// One trophy tile, restyled as a paper sticker pinned to the wooden
    /// shelf — sun ring around the lesson hero, ink stroke, soft drop shadow,
    /// caption underneath.
    @ViewBuilder
    private func lessonTrophyTile(_ trophy: LessonCompletionStore.TrophyRecord) -> some View {
        VStack(spacing: Spacing.sm) {
            ZStack {
                trophyTileDisk

                Group {
                    if let urlString = trophy.lessonHeroImageURL,
                       let url = URL(string: urlString) {
                        // V2-S4-06: off-main decode, capped at 300px for
                        // the small shelf tile, memory-cached on re-scroll.
                        LazyImageView(url: url, maxPixelSize: 300) { phase in
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                trophyPlaceholder
                            }
                        }
                    } else {
                        trophyPlaceholder
                    }
                }
                .clipShape(Circle())
                .padding(8) // Inset so image stays inside the sun + ink ring
            }
            .aspectRatio(1, contentMode: .fit)

            Text(trophy.trophyName)
                .font(NovaPalette.captionFont().weight(.semibold))
                .foregroundStyle(NovaPalette.classroomInk)
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
                    NovaPalette.classroomSun.opacity(0.85),
                    NovaPalette.classroomSchoolRed.opacity(0.65)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "trophy.fill")
                .font(.title)
                .foregroundStyle(NovaPalette.classroomInk)
        }
    }

    /// Earned-trophy disk. Prefers the painted earned-badge asset
    /// (`trophy_badge_disk_earned_45`) when it ships in the bundle so
    /// the disk reads as a true trophy medallion; otherwise falls
    /// back to the existing classroom-paper + sun-ring + ink-stroke
    /// composition. The lesson hero image still composites *inside*
    /// the disk via the surrounding ZStack regardless.
    @ViewBuilder
    private var trophyTileDisk: some View {
        if let asset = ClassroomRewardArtSlot.trophyBadgeDiskEarned.resolvedName {
            Image(asset)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
                .shadow(color: NovaPalette.classroomInk.opacity(0.20), radius: 5, x: 0, y: 3)
        } else {
            Circle()
                .fill(NovaPalette.classroomPaper)
                .overlay {
                    Circle()
                        .stroke(NovaPalette.classroomSun, lineWidth: 5)
                }
                .overlay {
                    Circle()
                        .stroke(NovaPalette.classroomInk, lineWidth: 2)
                }
                .shadow(color: NovaPalette.classroomInk.opacity(0.20), radius: 5, x: 0, y: 3)
        }
    }

    /// Wood-toned shelf panel that hosts a row/grid of trophy tiles.
    /// Mirrors the bookshelf object on the classroom home so trophies
    /// feel like they share furniture with the rest of the classroom.
    ///
    /// Layering (bottom → top):
    ///   1. `shelfPanelBackground` — `trophyCase` asset or wood-tinted
    ///      SwiftUI rect.
    ///   2. `shelfRowOverlay` — `trophyShelfRow` painted shelf row,
    ///      anchored to the bottom edge so each trophy tile reads as
    ///      sitting *on* a shelf rather than floating in the case.
    ///   3. The trophy tiles themselves.
    ///   4. SwiftUI fallback wood band + ink stroke when neither
    ///      painted asset has shipped, so the panel still has crisp
    ///      edges in the no-art build.
    @ViewBuilder
    private func shelfPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(Spacing.md)
            .frame(maxWidth: .infinity)
            .background(alignment: .bottom) { shelfRowOverlay }
            .background(shelfPanelBackground)
            .overlay(alignment: .bottom) {
                if ClassroomRewardArtSlot.trophyShelfRow.hasAsset == false
                    && ClassroomRewardArtSlot.trophyCase.hasAsset == false {
                    Rectangle()
                        .fill(NovaPalette.classroomWood)
                        .frame(height: 4)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.bottom, Spacing.sm)
                }
            }
            .overlay {
                if ClassroomRewardArtSlot.trophyCase.hasAsset == false {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(NovaPalette.classroomInk, lineWidth: 3)
                }
            }
            .shadow(color: NovaPalette.classroomInk.opacity(0.14), radius: 6, x: 0, y: 3)
    }

    /// Painted shelf-row overlay layered between the case background
    /// and the trophy tile grid. Anchored to the bottom edge of the
    /// panel so the row reads as a wall-mounted shelf the trophies
    /// rest on. Renders nothing when the asset has not shipped — the
    /// SwiftUI wood band in `shelfPanel` covers that case.
    @ViewBuilder
    private var shelfRowOverlay: some View {
        if let asset = ClassroomRewardArtSlot.trophyShelfRow.resolvedName {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.sm)
                .padding(.bottom, Spacing.sm)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// Painted shelf-panel backdrop. Prefers the painted trophy-case
    /// asset when it ships in the bundle so trophy tiles read as
    /// sitting inside a wall-mounted case; falls back to the existing
    /// wood-tinted SwiftUI rectangle when the asset is absent.
    @ViewBuilder
    private var shelfPanelBackground: some View {
        if let asset = ClassroomRewardArtSlot.trophyCase.resolvedName {
            Image(asset)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(NovaPalette.classroomWood.opacity(0.30))
        }
    }

    /// Trophy-room scene background. Uses the painted scene asset
    /// (orientation-aware) when available; otherwise the existing
    /// `novaBackground` token. Routed through GeometryReader so the
    /// portrait / landscape variants resolve at runtime without
    /// requiring layout-time orientation reads from the parent.
    private var trophyRoomBackground: some View {
        GeometryReader { proxy in
            let isPortrait = proxy.size.height >= proxy.size.width
            let slot: ClassroomRewardArtSlot = isPortrait
                ? .trophyRoomScenePortrait
                : .trophyRoomSceneLandscape
            ZStack {
                NovaPalette.novaBackground

                if let asset = slot.resolvedName ?? ClassroomRewardArtSlot.trophyRoomSceneLandscape.resolvedName {
                    Image(asset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    /// Paper-strap sticker label used above each shelf section. Gives every
    /// section the same "pinned note" identity as the classroom home.
    private func sectionLabel(
        text: String,
        icon: String,
        accent: Color,
        countSuffix: String? = nil
    ) -> some View {
        HStack(spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NovaPalette.classroomInk)
                    .accessibilityHidden(true)
                Text(text)
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(NovaPalette.classroomInk)
                if let countSuffix {
                    Text(countSuffix)
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(NovaPalette.classroomInk.opacity(0.55))
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.42))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(NovaPalette.classroomInk, lineWidth: 1.5)
            }
            .shadow(color: NovaPalette.classroomInk.opacity(0.14), radius: 2, x: 0, y: 1)

            Spacer()
        }
    }

    // MARK: - Sections

    /// Chalkboard-banner header. The room reads like the same classroom the
    /// kid just left — wooden frame around a chalkboard, chalk-dust title,
    /// streak as a chalk note, and a sun-tinted sticker for the badges-earned
    /// count so it lands as a "look what you got!" moment.
    private var headerCard: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("My Trophies")
                    .font(NovaPalette.displayFont(size: 28))
                    .foregroundStyle(NovaPalette.classroomChalkDust)

                HStack(spacing: Spacing.xs) {
                    streakFlameGlyph
                        .accessibilityHidden(true)
                    Text("\(viewModel.currentStreak) day streak")
                        .font(NovaPalette.bodyFont().weight(.semibold))
                        .foregroundStyle(NovaPalette.classroomChalkDust.opacity(0.85))
                }
            }

            Spacer(minLength: Spacing.md)

            earnedCountSticker
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(earnedCount) badges earned")
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(NovaPalette.classroomChalkboard.opacity(0.94))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NovaPalette.classroomInk, lineWidth: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(NovaPalette.classroomWood, lineWidth: 2)
                .padding(4)
        }
        .shadow(color: NovaPalette.classroomInk.opacity(0.18), radius: 8, x: 0, y: 4)
    }

    /// Streak flame glyph. Prefers the painted
    /// `streak_flame_sticker_45` sticker when available so the streak
    /// reads as a classroom sticker; otherwise the existing
    /// `flame.fill` SF symbol on `classroomSchoolRed`.
    @ViewBuilder
    private var streakFlameGlyph: some View {
        if let asset = ClassroomRewardArtSlot.streakFlameSticker.resolvedName {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
        } else {
            Image(systemName: "flame.fill")
                .foregroundStyle(NovaPalette.classroomSchoolRed)
        }
    }

    /// Sun-sticker count that sits on the chalkboard banner. Mirrors the
    /// classroom-home trophy-shelf badge so the surfaces feel like they
    /// share one sticker family.
    private var earnedCountSticker: some View {
        VStack(spacing: 2) {
            Text("\(earnedCount)")
                .font(NovaPalette.displayFont(size: 36))
                .foregroundStyle(NovaPalette.classroomInk)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("badges earned")
                .font(NovaPalette.captionFont().weight(.bold))
                .foregroundStyle(NovaPalette.classroomInk.opacity(0.78))
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NovaPalette.classroomSun)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(NovaPalette.classroomInk, lineWidth: 2)
        }
        .shadow(color: NovaPalette.classroomInk.opacity(0.20), radius: 4, x: 0, y: 2)
    }

    /// Three-across stat row — lessons completed, level, badges completion
    /// fraction. Trio adopts classroom tokens (sky / sun / leaf) so the row
    /// reads like a strip of classroom sticky-note tiles.
    private var statRow: some View {
        HStack(spacing: Spacing.md) {
            StatTile(
                icon: "book.fill",
                label: "Lessons",
                value: "\(viewModel.totalLessonsCompleted)",
                tint: NovaPalette.classroomSky
            )
            StatTile(
                icon: "star.fill",
                label: "Level",
                value: "Explorer",
                tint: NovaPalette.classroomSun
            )
            StatTile(
                icon: "checkmark.seal.fill",
                label: "Complete",
                value: "\(earnedCount)/\(viewModel.badges.count)",
                tint: NovaPalette.classroomLeaf
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
                sectionLabel(
                    text: "Achievements",
                    icon: "checkmark.seal.fill",
                    accent: NovaPalette.classroomSchoolRed
                )

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

    /// Empty classroom shelf with a single dashed-chalk cubby outlined in the
    /// middle. Reads as "this is where your first sticker will go" rather
    /// than "blank screen". Accessibility text mirrors the visual copy.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionLabel(
                text: "Achievement Shelf",
                icon: "rosette",
                accent: NovaPalette.classroomSun
            )

            shelfPanel {
                VStack(spacing: Spacing.md) {
                    emptyTrophySlotMarker

                    Text("First trophy goes here")
                        .font(NovaPalette.displayFont(size: 22))
                        .foregroundStyle(NovaPalette.classroomInk)
                        .multilineTextAlignment(.center)

                    Text("Finish a lesson and your first sticker lands on this shelf.")
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(NovaPalette.classroomInk.opacity(0.78))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Achievement shelf, empty")
        .accessibilityValue("Complete more activities to unlock classroom achievement badges.")
    }

    /// Empty-trophy-slot marker for the achievement-shelf empty
    /// state. Prefers the painted `trophy_empty_slot_45` sticker
    /// when available; otherwise falls back to the existing
    /// dashed-chalk circle + ink rosette glyph.
    @ViewBuilder
    private var emptyTrophySlotMarker: some View {
        if let asset = ClassroomRewardArtSlot.trophyEmptySlot.resolvedName {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
        } else {
            ZStack {
                Circle()
                    .strokeBorder(
                        NovaPalette.classroomInk.opacity(0.45),
                        style: StrokeStyle(lineWidth: 2.5, dash: [6, 5])
                    )
                    .frame(width: 96, height: 96)

                Image(systemName: "rosette")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(NovaPalette.classroomInk.opacity(0.55))
                    .accessibilityHidden(true)
            }
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
                    .foregroundStyle(NovaPalette.classroomInk)
                    .padding(8)
                    .background(
                        Circle().fill(tint.opacity(0.30))
                    )
                    .overlay {
                        Circle().stroke(NovaPalette.classroomInk, lineWidth: 1.5)
                    }
                    .accessibilityHidden(true)

                Text(value)
                    .font(NovaPalette.displayFont(size: 22))
                    .foregroundStyle(NovaPalette.classroomInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(label)
                    .font(NovaPalette.captionFont())
                    .foregroundStyle(NovaPalette.classroomInk.opacity(0.75))
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
    /// When the painted `trophyDetailCertificate` asset is in the
    /// bundle, the `NovaCard` shell is replaced with a certificate
    /// background so the detail sheet reads as a classroom certificate
    /// awarded to the kid; SwiftUI text continues to render live on
    /// top so badge titles, descriptions, and earned dates stay
    /// readable, accessible, and localizable.
    private var heroBlock: some View {
        Group {
            if let certificateAsset = ClassroomRewardArtSlot.trophyDetailCertificate.resolvedName {
                heroContent
                    .padding(PaintedArtContentInsets.rewardCertificateText)
                    .frame(maxWidth: .infinity)
                    .background(
                        Image(certificateAsset)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    )
                    .shadow(color: NovaPalette.ink.opacity(0.18), radius: 8, x: 0, y: 4)
            } else {
                NovaCard(accent: NovaPalette.sun) {
                    heroContent
                }
            }
        }
    }

    /// Inner contents of the hero block. Lifted out of `heroBlock` so
    /// the asset-backed and SwiftUI-card branches share the same
    /// composition without duplication.
    private var heroContent: some View {
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

    /// The big badge disc shown inside the progress ring. Mirrors
    /// `BadgeView.badgeCircle`'s contract — painted disk asset when
    /// available (`trophyBadgeDiskEarned` / `trophyBadgeDiskLocked`),
    /// otherwise the legacy SwiftUI gradient. The icon glyph always
    /// renders live on top so the badge identity survives both
    /// paths.
    private var heroBadgeDisc: some View {
        ZStack {
            heroDiscBackdrop

            // Sun glow only when the painted earned asset isn't in
            // place — the painted disk is expected to supply its own
            // highlight.
            if item.isEarned && heroDiskAssetName == nil {
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

            Image(systemName: item.badge.icon)
                .font(.system(size: 60, weight: .semibold))
                .foregroundStyle(
                    item.isEarned
                        ? NovaPalette.ink
                        : NovaPalette.ink.opacity(0.35)
                )
        }
    }

    @ViewBuilder
    private var heroDiscBackdrop: some View {
        if let asset = heroDiskAssetName {
            Image(asset)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
        } else {
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
                Circle()
                    .stroke(NovaPalette.ink, lineWidth: 2)
            }
        }
    }

    private var heroDiskAssetName: String? {
        let slot: ClassroomRewardArtSlot = item.isEarned
            ? .trophyBadgeDiskEarned
            : .trophyBadgeDiskLocked
        return slot.resolvedName
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

    /// Static cached formatter (V2-S4-06) — avoids re-allocating a
    /// `DateFormatter` on every badge-sheet recomputation.
    private static let earnedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    private func formatDate(_ date: Date) -> String {
        Self.earnedDateFormatter.string(from: date)
    }
}

#Preview {
    TrophyRoomView()
}
