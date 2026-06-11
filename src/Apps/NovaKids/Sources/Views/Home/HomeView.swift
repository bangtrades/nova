import SwiftUI
import NovaCore
import NovaClassroom

private let classroomV2Enabled = true

/// Home screen for authenticated users.
///
/// Displays welcome greeting, featured lesson, continue-learning block,
/// learning paths, and a quick-stats row. Optimized for iPad with large
/// touch targets. As of S11-05 the screen is built from the S11-03 design
/// system primitives — `NovaCard` for surfaces, Bangers via
/// `NovaPalette.displayFont(size:)` for headlines, and `Spacing.*` for
/// consistent vertical rhythm.
public struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var apiRouter: APIRouter
    @EnvironmentObject private var appState: KidsAppState
    @EnvironmentObject private var completionStore: LessonCompletionStore
    @State private var classroomPath: [ClassroomDestination] = []
    @State private var classroomPlaceholderMessage: String?

    public init() {}

    public var body: some View {
        NavigationStack(path: $classroomPath) {
            rootContent
            .novaNavigationStyle(title: classroomV2Enabled ? "" : "Nova Kids")
            .navigationDestination(for: ClassroomDestination.self) { destination in
                classroomDestination(destination)
            }
            .alert("Classroom preview", isPresented: placeholderAlertBinding) {
                Button("OK", role: .cancel) {
                    classroomPlaceholderMessage = nil
                }
            } message: {
                Text(classroomPlaceholderMessage ?? "")
            }
            // S11-19 wire-up: attach the router + currently-selected child
            // and kick off the first fetch. `attach` is idempotent so a tab
            // re-select (triggers `.task` again) is a no-op after the first.
            .task {
                viewModel.attach(apiRouter: apiRouter, childId: appState.currentChild?.id)
                await viewModel.refresh()
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if classroomV2Enabled {
            classroomHome
        } else {
            classicHome
        }
    }

    private var classroomHome: some View {
        ZStack(alignment: .top) {
            ClassroomSceneView(
                model: classroomSceneModel,
                onSelect: handleClassroomDestination(_:)
            )

            if let error = viewModel.loadError {
                ClassroomErrorBanner(
                    message: error.errorDescription ?? "Something went wrong",
                    context: "home"
                ) { Task { await viewModel.refresh() } }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    /// Resolve the classroom scene model. The default age band comes
    /// from the currently selected child profile via
    /// `ClassroomAgeBand.forChildProfile(_:)` — a 4-5 child gets the
    /// preschool classroom, a 6-7 child gets the maker lab. When no
    /// profile is loaded yet (cold launch before sign-in) the helper
    /// falls back to `.classroom45` so the experience stays unchanged
    /// from the previous shipping behavior.
    ///
    /// In developer runs the `NOVA_CLASSROOM_FORCE_AGE_BAND` env var
    /// re-writes the resulting model with the forced age band so the
    /// engineer can preview 6–7 / 8+ artwork without poking at backend
    /// profile data. The override is *only* read from `ProcessInfo`,
    /// has no UI affordance, and degrades silently to the default when
    /// the variable is unset or holds an unrecognized value.
    private var classroomSceneModel: ClassroomSceneModel {
        let baseModel = ClassroomSceneModel.home(
            currentLesson: viewModel.currentLesson,
            learningPaths: viewModel.learningPaths,
            lessons: viewModel.allLessons,
            completedLessonIds: completedLessonIds,
            trophyCount: trophyCount,
            ageBand: ClassroomAgeBand.forChildProfile(appState.currentChild)
        )

        guard let forcedBand = ClassroomAgeBand.developerForcedOverride() else {
            return baseModel
        }

        return ClassroomSceneModel(
            id: baseModel.id,
            ageBand: forcedBand,
            objects: baseModel.objects,
            activePrompt: baseModel.activePrompt
        )
    }

    private var classicHome: some View {
        ZStack {
            NovaPalette.novaBackground
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    WelcomeHeader(childName: viewModel.childName)

                    // S11-19: fetch-error banner. Matches the language
                    // of LessonsView / DashyView — page fill + ink
                    // stroke + coral icon + Try Again on .novaSecondary.
                    if let error = viewModel.loadError {
                        ClassroomErrorBanner(
                    message: error.errorDescription ?? "Something went wrong",
                    context: "home"
                ) { Task { await viewModel.refresh() } }
                    }

                    // Featured lesson — NavigationLink owns the tap so
                    // the card itself stays "content, not control".
                    if let featured = viewModel.featuredLesson {
                        NavigationLink {
                            FlipbookView(lesson: featured)
                        } label: {
                            FeaturedLessonCard(lesson: featured)
                        }
                        .buttonStyle(.plain)
                    }

                    ContinueLearningSection(
                        currentLesson: viewModel.currentLesson,
                        progress: viewModel.progressPercentage
                    )

                    if !viewModel.learningPaths.isEmpty {
                        LearningPathRow(paths: viewModel.learningPaths)
                    }

                    QuickStatsView()

                    Spacer(minLength: Spacing.lg)
                }
                .padding(Spacing.lg)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    private var placeholderAlertBinding: Binding<Bool> {
        Binding(
            get: { classroomPlaceholderMessage != nil },
            set: { isPresented in
                if !isPresented {
                    classroomPlaceholderMessage = nil
                }
            }
        )
    }

    private func handleClassroomDestination(_ destination: ClassroomDestination) {
        switch destination {
        case .placeholder(let message):
            classroomPlaceholderMessage = message
        default:
            classroomPath.append(destination)
        }
    }

    @ViewBuilder
    private func classroomDestination(_ destination: ClassroomDestination) -> some View {
        switch destination {
        case .continueLesson(let lessonId):
            if let lesson = viewModel.currentLesson, lesson.id == lessonId {
                FlipbookView(lesson: lesson)
            } else {
                EmptyStateView(
                    title: "No lesson ready",
                    subtitle: "Ask a grown-up to add a lesson.",
                    icon: "sparkles"
                )
                // V2-S4-F2: voiced empty state — a pre-literate kid who
                // taps the chalkboard with no lesson queued hears why
                // it's empty instead of reading silent text.
                .narrate("homeEmpty")
            }
        case .lesson(let lessonId):
            if let lesson = lesson(matching: lessonId) {
                FlipbookView(lesson: lesson)
            } else {
                EmptyStateView(
                    title: "Lesson not found",
                    subtitle: "Ask a grown-up to refresh your classroom.",
                    icon: "sparkles"
                )
                .narrate("lessonNotFound")
            }
        case .lessonLibrary:
            ClassroomLessonLibraryView(
                paths: viewModel.learningPaths,
                lessons: viewModel.allLessons,
                completedLessonIds: completedLessonIds
            ) { lesson in
                classroomPath.append(.lesson(lesson.id))
            }
            .navigationTitle("Bookshelf")
            .navigationBarTitleDisplayMode(.inline)
            .narrate("classroomBookshelf")
        case .dashy:
            DashyView()
        case .trophies:
            TrophyRoomView()
        case .voicePicker:
            VoicePickerView(
                childId: appState.currentChild?.id,
                onDone: {}
            )
        case .placeholder(let message):
            EmptyStateView(
                title: "Coming soon",
                subtitle: message,
                icon: "sparkles"
            )
            .narrate("comingSoon")
        }
    }

    private func lesson(matching lessonId: UUID) -> Lesson? {
        if let currentLesson = viewModel.currentLesson, currentLesson.id == lessonId {
            return currentLesson
        }

        return viewModel.allLessons.first { $0.id == lessonId }
    }

    private var completedLessonIds: Set<UUID> {
        Set(
            viewModel.allLessons
                .filter { lesson in
                    completionStore.hasCompleted(
                        childId: appState.currentChild?.id,
                        lessonId: lesson.id
                    )
                }
                .map(\.id)
        )
    }

    private var trophyCount: Int {
        completionStore.trophyCount(for: appState.currentChild?.id)
    }

}

/// Quick stats row showing badges and achievements.
///
/// Each `StatBadge` keeps its per-metric color fill (points = sun, lessons =
/// blue, streak = orange) but adopts the `NovaCard` visual language
/// underneath: 20pt corner radius + 2pt ink stroke + paper shadow. The
/// colored fill stays because that's how a kid tells at a glance which
/// number means what.
private struct QuickStatsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm + 4) {
            Text("Achievements")
                .font(NovaPalette.displayFont(size: 24))
                .foregroundStyle(NovaPalette.ink)

            HStack(spacing: Spacing.sm + 4) {
                StatBadge(
                    icon: "star.fill",
                    value: "42",
                    label: "Points",
                    tint: NovaPalette.sun
                )

                StatBadge(
                    icon: "book.fill",
                    value: "6",
                    label: "Lessons Done",
                    tint: NovaPalette.Category.blue
                )

                StatBadge(
                    icon: "flame.fill",
                    value: "3",
                    label: "Day Streak",
                    tint: NovaPalette.Category.orange
                )
            }
        }
    }
}

/// Individual stat tile — keeps its category tint as the fill, adopts NovaCard's
/// stroke + radius language so the row sits visually in the same family as
/// the rest of the screen.
private struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    private let cornerRadius: CGFloat = 20

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(NovaPalette.ink)
                .accessibilityHidden(true)

            Text(value)
                .font(NovaPalette.displayFont(size: 28))
                .foregroundStyle(NovaPalette.ink)

            Text(label)
                .font(NovaPalette.captionFont())
                .foregroundStyle(NovaPalette.ink.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(
            tint,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(NovaPalette.ink, lineWidth: 2)
        }
        .shadow(color: NovaPalette.ink.opacity(0.08), radius: 6, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

#Preview {
    HomeView()
}
