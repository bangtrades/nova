import SwiftUI
import NovaCore
import NovaVoice

/// Polished home screen with learning path sections, progress tracking, and time-based greetings.
///
/// Displays horizontal scroll sections by learning path, a stage badge, the
/// continue-learning hero, and a personalized greeting. Supports pull-to-
/// refresh for syncing. As of S11-05 every surface on this screen is
/// expressed in the Nova design language — Bangers display font for the
/// greeting, `NovaCard` for surfaces, `Spacing.*` for vertical rhythm.
public struct EnhancedHomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var apiRouter: APIRouter
    @EnvironmentObject private var appState: KidsAppState

    /// S13-08: surface the voice picker from a small settings affordance.
    /// Sheet because it's a focused decision; dismiss returns to home.
    @State private var showVoicePicker = false

    // S12-01: iPad-vs-iPhone tile sizing. Hero-row lesson cards need more
    // presence on iPad — kids see them from 18" away on a shared family
    // device, not 8" on a phone. `.regular` bumps the card to 196×224 so
    // it reads as a full scene rather than a thumbnail; `.compact` stays
    // at the phone-calibrated 140×160 the art was drawn for.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var lessonCardWidth: CGFloat {
        horizontalSizeClass == .regular ? 196 : 140
    }
    private var lessonCardHeight: CGFloat {
        horizontalSizeClass == .regular ? 224 : 160
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                NovaPalette.novaBackground
                    .ignoresSafeArea()

                // Loading takes precedence over empty-state so the skeleton
                // doesn't flash the empty copy during pull-to-refresh.
                if viewModel.isLoading {
                    LoadingSkeletonView(itemCount: 4, isGrid: false)
                        .accessibilityLabel("Loading your home screen")
                } else if viewModel.learningPaths.isEmpty && viewModel.allLessons.isEmpty {
                    emptyStateView
                } else {
                    content
                }

                // S11-19: Error overlay sits above `content` but below any
                // nav chrome. Tiny surface so it doesn't eclipse the hero.
                if let error = viewModel.loadError, !viewModel.isLoading {
                    VStack {
                        ClassroomErrorBanner(
                            message: error.errorDescription ?? "Something went wrong",
                            context: "home"
                        ) { Task { await viewModel.refresh() } }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.top, Spacing.md)
                        Spacer()
                    }
                }
            }
            // Enhanced Home owns its chrome with the `greetingHeader` block.
            // Empty title keeps the nav bar clean — modifier renders no
            // principal item when `title` is empty.
            .novaNavigationStyle()
            // S13-08: small settings gear in the top trailing slot opens
            // the voice picker as a sheet. Stays out of the way for kids
            // who never need it (they get the default Nova voice on first
            // play); reachable for any kid who wants to try the others.
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showVoicePicker = true
                    } label: {
                        Image(systemName: "speaker.wave.2.bubble.fill")
                            .font(.title3)
                            .foregroundStyle(NovaPalette.novaOrange)
                    }
                    .accessibilityLabel("Pick a voice")
                    .accessibilityHint("Opens the voice picker so you can choose who tells your stories")
                }
            }
            .sheet(isPresented: $showVoicePicker) {
                NavigationStack {
                    VoicePickerView(
                        childId: appState.currentChild?.id,
                        onDone: { showVoicePicker = false }
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showVoicePicker = false }
                        }
                    }
                }
            }
            // S11-19 wire-up point.
            .task {
                viewModel.attach(apiRouter: apiRouter, childId: appState.currentChild?.id)
                await viewModel.refresh()
            }
            // S14-VF-02: auto-narrate the home line on appear so a
            // pre-literate kid hears "Hi! I'm Dashy. Pick a topic to
            // start learning!" instead of staring at silent text labels.
            // 60s cooldown means re-navigating back doesn't re-narrate.
            .narrate("home")
        }
    }

    // MARK: - Root content

    private var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.lg) {
                greetingHeader
                    .padding(.horizontal, Spacing.lg)

                stageBadge
                    .padding(.horizontal, Spacing.lg)

                if let currentLesson = viewModel.currentLesson {
                    ContinueLearningSection(
                        currentLesson: currentLesson,
                        progress: viewModel.progressPercentage
                    )
                    .padding(.horizontal, Spacing.lg)
                }

                if !viewModel.learningPaths.isEmpty {
                    ForEach(viewModel.learningPaths) { path in
                        learningPathSection(path)
                    }
                }

                Spacer(minLength: Spacing.lg)
            }
            .padding(.vertical, Spacing.lg)
        }
        .refreshable {
            await performRefresh()
        }
    }

    // MARK: - Subviews

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(timeBasedGreeting)
                .font(NovaPalette.displayFont(size: 32))
                .foregroundStyle(NovaPalette.ink)

            Text("Ready to learn something awesome today?")
                .font(NovaPalette.bodyFont())
                .foregroundStyle(NovaPalette.ink.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Stage badge — unlike other surfaces this one keeps a rich
    /// gradient fill (progression visual) rather than using `NovaCard`. We
    /// still add the 20pt radius + 2pt ink stroke + soft shadow so it reads
    /// as part of the same family.
    private var stageBadge: some View {
        HStack(spacing: Spacing.sm + 4) {
            Image(systemName: stageIcon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Learning Stage")
                    .font(NovaPalette.captionFont())
                    .foregroundStyle(.white.opacity(0.85))

                Text(stageLabel)
                    .font(NovaPalette.displayFont(size: 22))
                    .foregroundStyle(.white)
            }

            Spacer()

            Text("\(Int(viewModel.progressPercentage * 100))%")
                .font(NovaPalette.displayFont(size: 22))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .background(
            LinearGradient(
                colors: [NovaPalette.Category.blue, NovaPalette.Category.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(NovaPalette.ink, lineWidth: 2)
        }
        .shadow(color: NovaPalette.ink.opacity(0.08), radius: 6, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Learning stage: \(stageLabel)")
        .accessibilityValue("\(Int(viewModel.progressPercentage * 100)) percent complete")
    }

    /// Group lessons by learning path once so the per-path sections don't
    /// re-compute the grouping on every render.
    private var lessonsByPath: [UUID: [Lesson]] {
        Dictionary(
            grouping: viewModel.allLessons.filter { $0.pathId != nil },
            by: { $0.pathId! }
        )
    }

    private func learningPathSection(_ path: LearningPath) -> some View {
        let pathLessons = lessonsByPath[path.id] ?? []

        return VStack(alignment: .leading, spacing: Spacing.sm + 4) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(path.title)
                    .font(NovaPalette.displayFont(size: 24))
                    .foregroundStyle(NovaPalette.ink)

                // Until per-path completion lands in HomeViewModel (scoped to
                // S12's lesson-progress work), show the honest lesson count
                // instead of a hardcoded "3 of 8". The ProgressView also drops
                // — a progress bar without real progress data is worse than
                // no progress bar, because it tells the child something that
                // isn't true about their own learning.
                HStack(spacing: Spacing.sm) {
                    Text(pathLessons.count == 1 ? "1 lesson" : "\(pathLessons.count) lessons")
                        .font(NovaPalette.captionFont())
                        .foregroundStyle(NovaPalette.ink.opacity(0.7))
                }
            }
            .padding(.horizontal, Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.sm + 4) {
                    ForEach(pathLessons) { lesson in
                        NavigationLink {
                            FlipbookView(lesson: lesson)
                        } label: {
                            lessonCard(
                                lesson,
                                pathColor: NovaPalette.pathColor(for: path.id.uuidString)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
            .scrollTargetBehavior(.viewAligned)
        }
        .padding(.vertical, Spacing.sm + 4)
    }

    private func lessonCard(_ lesson: Lesson, pathColor: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                stageTagView
                Spacer()
            }

            Spacer()

            Text(lesson.title)
                .font(NovaPalette.smallHeadingFont())
                .foregroundStyle(NovaPalette.ink)
                .lineLimit(2)

            HStack(spacing: Spacing.xs) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index == 0 ? pathColor : NovaPalette.ink.opacity(0.25))
                        .frame(width: 4, height: 4)
                }
                Spacer()
            }
        }
        .padding(Spacing.sm + 4)
        .frame(width: lessonCardWidth, height: lessonCardHeight)
        .background(
            NovaPalette.page,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(NovaPalette.ink, lineWidth: 2)
        }
        .shadow(color: NovaPalette.ink.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    private var stageTagView: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundStyle(NovaPalette.ink)
                .accessibilityHidden(true)

            Text("Explorer")
                .font(NovaPalette.captionFont())
                .foregroundStyle(NovaPalette.ink)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            NovaPalette.sun,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "book.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(NovaPalette.Category.blue)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.sm) {
                Text("Welcome! Let's start exploring AI together!")
                    .font(NovaPalette.displayFont(size: 28))
                    .foregroundStyle(NovaPalette.ink)
                    .multilineTextAlignment(.center)

                Text("Choose your first learning path to begin your adventure.")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(NovaPalette.ink.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.lg)

            Button("Browse Learning Paths") {
                // TODO: wire up when the Paths screen is ready.
            }
            .novaPrimary()
            .padding(.horizontal, Spacing.xl + 8)

            Spacer()
        }
    }

    // MARK: - Helpers

    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning!"
        case 12..<17: return "Good afternoon!"
        default:      return "Good evening!"
        }
    }

    /// Stage is derived from `viewModel.progressPercentage`, which is a 0–1
    /// fractional value (not 0–100). Historically this switch compared against
    /// 0..<25 etc., which meant every kid was stuck at "Explorer" forever
    /// because 0.35 is always < 25. Ranges now match the data contract.
    private var stageLabel: String {
        switch viewModel.progressPercentage {
        case 0..<0.25:   return "Explorer"
        case 0.25..<0.5: return "Thinker"
        case 0.5..<0.75: return "Maker"
        default:         return "Creator"
        }
    }

    private var stageIcon: String {
        switch viewModel.progressPercentage {
        case 0..<0.25:   return "binoculars.fill"
        case 0.25..<0.5: return "lightbulb.fill"
        case 0.5..<0.75: return "hammer.fill"
        default:         return "sparkles"
        }
    }

    /// `.refreshable` calls this from its own Task; `viewModel.refresh()` owns
    /// the `isLoading` flag and the intentional 400ms minimum so the skeleton
    /// renders long enough to read. No local `@State isRefreshing` mirror is
    /// needed — the single source of truth lives on the ViewModel.
    private func performRefresh() async {
        await viewModel.refresh()
    }
}

#Preview {
    EnhancedHomeView()
        .environmentObject(VoiceManager(speechSynthesizer: SpeechSynthesizer()))
}
