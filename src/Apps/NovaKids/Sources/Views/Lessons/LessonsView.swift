import SwiftUI
import NovaCore

/// Lessons tab showing all available lessons in a Pinterest-style masonry grid.
///
/// S11-12 refresh lands three things on top of the existing structure:
///   1. `LessonTileView` now consumes the DS visual language (ink outline +
///      accent stripe + page background + optional "NEW" badge + iPad hover).
///   2. `PathFilterPill` replaces the earlier `PathFilterButton` — ink-outline
///      default, coral-fill when selected, keyed to the 3+1 palette.
///   3. Spacing routes through the `Spacing` enum so the grid breathes at the
///      same rhythm as Home / Trophy / Quiz.
///
/// Masonry math is untouched — `MasonryGrid` still derives column width from
/// the enclosing `GeometryReader`, and tile content size still drives row
/// height, so the gestalt preserves even as the tile chrome changes.
public struct LessonsView: View {
    @StateObject private var viewModel = LessonsViewModel()
    @EnvironmentObject private var apiRouter: APIRouter
    @EnvironmentObject private var completionStore: LessonCompletionStore
    @EnvironmentObject private var appState: KidsAppState
    @State private var selectedLesson: Lesson?
    @State private var showFlipbook = false

    // S12-01: iPad-vs-iPhone grid density. `.regular` (iPad full-screen, not
    // split) gets 3 columns so the masonry actually uses the extra real
    // estate instead of stretching two giant tiles; `.compact` (iPhone, or
    // iPad in split) stays at the 2-column count the tile art is designed
    // around.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                NovaPalette.novaBackground
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        // S11-19: surface fetch failures without hiding cached
                        // content. `loadError` is typed `APIError?` so the
                        // banner can speak the semantic message (unauthorized /
                        // not found / network down) instead of a raw string.
                        if let error = viewModel.loadError {
                            ClassroomErrorBanner(
                                message: error.errorDescription ?? "Something went wrong",
                                context: "lessons"
                            ) { Task { await viewModel.refresh() } }
                            .padding(.horizontal, Spacing.lg)
                            .padding(.top, Spacing.md)
                        }

                        if viewModel.isLoading {
                            // S11-14: pull-to-refresh skeleton. Grid mode
                            // lines up with the 2-column masonry below, so
                            // the shimmer reads as "those lesson tiles are
                            // coming back" instead of a generic spinner.
                            // `LoadingSkeletonView` applies its own 20pt
                            // padding, so no extra wrapper needed.
                            LoadingSkeletonView(itemCount: 6, isGrid: true)
                        } else {
                            lessonContent
                        }
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .novaNavigationStyle(title: "Lessons")
            // S11-19: `.task` is the wire-up point. Attach is idempotent so
            // re-appearing the view (tab switch) is a no-op after first hit;
            // `refresh()` then does the real fetch (or mock fallback when no
            // router is present — e.g. `#Preview`).
            .task {
                viewModel.attach(apiRouter: apiRouter)
                await viewModel.refresh()
            }
            // S14-VF-02: kid hears "These are the lessons. Tap one to
            // start!" on entry. 60s cooldown — bouncing back from a
            // flipbook view doesn't re-narrate.
            .narrate("lessons")
        }
    }

    /// The non-loading body — filter row + masonry grid.
    ///
    /// Extracted so the `isLoading` branch above can cleanly swap between
    /// skeleton and real content without nesting another VStack layer.
    @ViewBuilder
    private var lessonContent: some View {
        // Learning-paths filter row
        if !viewModel.learningPaths.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Filter by Path")
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(NovaPalette.ink)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        // "All" sentinel — maps to `selectedPath == nil`.
                        PathFilterPill(
                            title: "All",
                            isSelected: viewModel.selectedPath == nil
                        ) {
                            viewModel.selectPath(nil)
                        }

                        ForEach(viewModel.learningPaths) { path in
                            PathFilterPill(
                                title: path.title,
                                isSelected: viewModel.selectedPath?.id == path.id
                            ) {
                                viewModel.selectPath(path)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.xs)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)
        }

        // Masonry grid
        if viewModel.filteredLessons.isEmpty {
            EmptyStateView(
                title: "No lessons yet!",
                subtitle: "Ask your parent to add some!",
                icon: "sparkles"
            )
            .frame(minHeight: 400)
        } else {
            MasonryGrid(
                items: viewModel.filteredLessons,
                columns: horizontalSizeClass == .regular ? 3 : 2,
                spacing: Spacing.md
            ) { lesson in
                NavigationLink(destination: {
                    FlipbookView(lesson: lesson)
                }) {
                    // S12-12: omit the trailing onTap closure so
                    // LessonTileView skips its inner Button wrapper —
                    // otherwise the Button intercepts the tap and the
                    // NavigationLink never fires (manifested as "tapping
                    // a lesson does nothing"). The previous closure set
                    // `selectedLesson` + `showFlipbook` but no .sheet
                    // modifier ever read those — leftover from a
                    // sheet-based nav before NavigationLink replaced it.
                    LessonTileView(
                        lesson: lesson,
                        // S13: completion now reads from
                        // LessonCompletionStore keyed on the active
                        // child. Replaces the previous mock
                        // (lesson.id.hashValue % 3 == 0) which gave
                        // a fake checkmark to ~1/3 of lessons.
                        isComplete: completionStore.hasCompleted(
                            childId: appState.currentChild?.id,
                            lessonId: lesson.id
                        )
                    )
                }
            }
            .padding(Spacing.lg)
        }
    }
}

/// Learning-path filter pill.
///
/// S11-12 redesign — ink-outline/page-fill by default, coral-fill/page-text
/// when selected. The silhouette is a capsule (not a rounded-rect) so the
/// ink stroke reads as a drawn outline rather than a button. Matches the
/// "selection = coral" rule established by the Quiz answer chip in S11-06.
private struct PathFilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NovaPalette.smallHeadingFont())
                .foregroundStyle(isSelected ? NovaPalette.page : NovaPalette.ink)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.md)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? NovaPalette.coral : NovaPalette.page)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(NovaPalette.ink, lineWidth: 2)
                )
        }
        .buttonStyle(PlainButtonStyle())
        // Light spring on selection matches the "commit" feel of the rest of
        // the app — subtle, not bouncy. Respects reduce-motion.
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    LessonsView()
}
