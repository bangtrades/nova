import SwiftUI
import NovaCore
import NovaVoice

/// Full-screen flipbook view for card navigation.
///
/// Displays cards with horizontal swipe navigation using TabView page style.
/// Includes progress tracking, progress dots, and back button.
public struct FlipbookView: View {
    /// The lesson to display.
    let lesson: Lesson

    @StateObject private var viewModel: FlipbookViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject var voiceManager: VoiceManager
    @EnvironmentObject private var apiRouter: APIRouter
    @EnvironmentObject private var completionStore: LessonCompletionStore
    @EnvironmentObject private var appState: KidsAppState

    // S13: celebration state. Gates the fullScreenCover that takes over
    // the screen when the kid hits Finish. `isFirstTime` is captured at
    // record time so re-completes get the softer welcome-back beat.
    @State private var showCelebration = false
    @State private var celebrationIsFirstTime = true

    public init(lesson: Lesson) {
        self.lesson = lesson
        // Initialize with a default voice manager; will be overridden by environment
        _viewModel = StateObject(wrappedValue: FlipbookViewModel(
            lesson: lesson,
            voiceManager: VoiceManager(speechSynthesizer: SpeechSynthesizer())
        ))
    }

    public var body: some View {
        ZStack {
            classroomLessonBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header — pass current card type so the Bangers label + color
                // bar track the TabView's selected card (S11-11).
                FlipbookHeader(
                    lesson: lesson,
                    cardType: viewModel.currentCard?.type
                ) {
                    dismiss()
                }
                .padding(20)

                // No top Spacer here — the lesson book / loading /
                // empty / error states should sit directly under the
                // header so the workbook art is not pushed into a
                // small letterbox in the vertical middle of the
                // screen. The bottom Spacer below the shell still
                // anchors the progress dots + Prev/Next pair to the
                // bottom of the viewport.

                // S11-19: error banner surfaces fetch failures without
                // killing the card deck. Matches the Home / Lessons /
                // Trophy language — page fill + ink stroke + coral icon +
                // .novaSecondary() retry.
                if let error = viewModel.loadError {
                    ClassroomErrorBanner(
                        message: error.errorDescription ?? "Something went wrong",
                        context: "cards"
                    ) { Task { await viewModel.retryLoad() } }
                    .padding(.horizontal, Spacing.lg)
                }

                // Classroom loading state — reads as "the teacher is
                // setting up today's lesson on the chalkboard" so the
                // prep moment stays in-world rather than feeling like a
                // generic spinner / skeleton grid.
                if viewModel.isLoading && viewModel.cards.isEmpty {
                    Spacer()
                    classroomLessonLoading
                        .padding(Spacing.lg)
                    Spacer()
                }

                // Card display with TabView for swiping. The
                // `LessonBookReaderShell` wraps the swipe deck in a
                // workbook silhouette — wood book cover, paper pages,
                // center crease, page corner curls, bookmark ribbon,
                // and a desk slab at the bottom — so the lesson reader
                // feels like an open book on the kid's desk rather
                // than a generic card on a screen.
                if viewModel.cards.isEmpty == false {
                    LessonBookReaderShell {
                        ZStack(alignment: .topTrailing) {
                            TabView(selection: $viewModel.currentCardIndex) {
                                ForEach(0..<viewModel.cards.count, id: \.self) { index in
                                    let card = viewModel.cards[index]

                                    ZStack {
                                        if card.type == .story {
                                            StoryCardView(card: card)
                                        } else if card.type == .concept {
                                            ConceptCardView(card: card)
                                        } else if card.type == .experiment {
                                            ExperimentCardView(card: card)
                                        } else if card.type == .quiz {
                                            QuizCardView(card: card)
                                        } else if card.type == .voice {
                                            VoiceCardView(card: card)
                                        } else {
                                            // Fallback for other card types
                                            ZStack {
                                                NovaPalette.novaBlue.opacity(0.2)
                                                VStack {
                                                    Image(systemName: "questionmark.circle")
                                                        .font(.largeTitle)
                                                        .foregroundStyle(NovaPalette.novaBlue)
                                                        .accessibilityHidden(true)
                                                    Text("Card Type: \(card.type.rawValue)")
                                                        .font(NovaPalette.bodyFont())
                                                        .foregroundStyle(.primary)
                                                }
                                            }
                                        }
                                    }
                                    .transition(
                                        .asymmetric(
                                            insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)
                                        )
                                    )
                                    .tag(index)
                                    .onAppear {
                                        viewModel.markCurrentCardComplete()
                                    }
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                            .indexViewStyle(.page(backgroundDisplayMode: .never))
                            .padding(20)

                            // Dashy Hint Button - top right
                            DashyHintButton(showHintSheet: $viewModel.showDashyHint)
                                .padding(20)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                } else if viewModel.isLoading == false {
                    classroomEmptyState
                        .padding(.horizontal, Spacing.lg)
                }

                Spacer()

                // Progress dots — S12-01 caps the dot row at 600pt so the
                // marker spread stays readable on iPad instead of 16 dots
                // walking from edge to edge of a 1366pt landscape.
                if viewModel.cards.isEmpty == false {
                    CardProgressDots(
                        currentIndex: viewModel.currentCardIndex,
                        totalCards: viewModel.cards.count
                    )
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                }

                // Navigation buttons — workbook page-turn pair. Each
                // button reads as a paper page tab: classroom-paper
                // fill, classroom-ink stroke, classroom-school-red
                // chevron + label. The Finish variant swaps to a
                // sun-yellow sticker so the lesson-complete moment
                // stands out from the routine page-turn pair.
                // S12-01 caps the pair at 600pt so the two buttons
                // don't land on opposite ends of an iPad landscape
                // viewport.
                if viewModel.cards.isEmpty == false {
                    HStack(spacing: Spacing.md) {
                        let isAtStart = viewModel.currentCardIndex == 0
                        let isAtEnd = viewModel.isLastCard

                        // Previous — paper page-turn going back.
                        Button {
                            // S11-16: card index transition animates under default,
                            // snaps instant under reduce-motion. The TabView page
                            // slide is ambient motion — progress dots + card
                            // content change both convey the navigation either way.
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                                viewModel.previousCard()
                            }
                        } label: {
                            workbookPageTurnLabel(
                                title: "Previous",
                                direction: .leading,
                                tone: .paper
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isAtStart)
                        .opacity(isAtStart ? 0.5 : 1.0)
                        .accessibilityLabel("Previous card")

                        // Next / Finish — paper page-turn forward, or
                        // sun-sticker Finish on the last card.
                        // S13: when isAtEnd, fire the lesson-complete
                        // flow instead of advancing the index.
                        Button {
                            if isAtEnd {
                                finishLesson()
                            } else {
                                // S11-16: matches Previous — reduce-motion
                                // turns the card swap into an instant
                                // state flip rather than a horizontal slide.
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                                    viewModel.nextCard()
                                }
                            }
                        } label: {
                            workbookPageTurnLabel(
                                title: isAtEnd ? "Finish" : "Next",
                                direction: .trailing,
                                tone: isAtEnd ? .finish : .paper
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isAtEnd ? "Finish lesson" : "Next card")
                    }
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Flipbook viewer")
        .accessibilityValue("Card \(viewModel.currentCardIndex + 1) of \(viewModel.cards.count)")
        .sheet(isPresented: $viewModel.showDashyHint) {
            DashyHintSheet(hintText: viewModel.currentHint)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // S11-19 wire-up. `attach` is idempotent; `loadCardsIfNeeded`
        // short-circuits once `cards` is non-empty so a re-entered view
        // doesn't re-fetch.
        .task {
            viewModel.attach(apiRouter: apiRouter)
            await viewModel.loadCardsIfNeeded()
        }
        // S14-VF-02: kid hears "Let's begin! Tap the arrow to see the
        // first card." on flipbook entry. Card content has its own
        // narration (the speaker icon on each card) — this is just the
        // entry beat that signals "lesson is starting." 60s cooldown
        // means re-entering the same lesson within a minute (e.g. the
        // kid swiped Done, then opened the same lesson) doesn't
        // re-narrate — but a fresh lesson always does.
        .narrate("lessonDetail")
        // S13: lesson-complete celebration. `fullScreenCover` takes the
        // whole screen so the moment is the focal interaction — kid
        // can't dismiss accidentally by tapping outside, has to commit
        // by hitting Continue. Hero image pulled from the lesson's
        // first card so the trophy art is contextual to what the kid
        // just learned about.
        .fullScreenCover(isPresented: $showCelebration) {
            LessonCompleteCelebration(
                trophyName: trophyName(for: lesson.title),
                heroImageURL: viewModel.cards.first?.imageURL,
                isFirstTime: celebrationIsFirstTime,
                onContinue: {
                    showCelebration = false
                    // After celebration dismissal, return to Lessons tab
                    // so the kid sees their freshly-checkmarked tile.
                    dismiss()
                }
            )
        }
    }

    /// S13: handle Finish-button tap on the last card.
    /// Records completion in the local store (which immediately updates
    /// LessonsView's checkmark + TrophyRoom's tile list reactively),
    /// triggers the celebration overlay, and returns. The dismiss-to-
    /// Lessons-tab happens when the kid taps Continue inside the
    /// celebration view.
    private func finishLesson() {
        // S13: pass childId optional through to the store. The store
        // resolves nil to a per-device fallback UUID so writes and
        // reads always agree on the key, even when no profile is
        // selected. (Previous shape duplicated the fallback locally,
        // which silently diverged from LessonsView/TrophyRoomView's
        // read paths and made the trophy invisible after Continue.)
        let isFirstTime = completionStore.recordCompletion(
            childId: appState.currentChild?.id,
            lessonId: lesson.id,
            lessonTitle: lesson.title,
            lessonHeroImageURL: viewModel.cards.first?.imageURL
        )
        celebrationIsFirstTime = isFirstTime
        showCelebration = true
    }

    /// Derives a kid-friendly trophy name from the lesson title.
    /// Strips the Wikipedia-source suffix that comes from the URL
    /// scrape so "Sky - Simple English Wikipedia, the free
    /// encyclopedia" reads as "Sky Champion" on the trophy reveal.
    private func trophyName(for lessonTitle: String) -> String {
        let cleanTitle = lessonTitle
            .replacingOccurrences(of: " - Simple English Wikipedia, the free encyclopedia", with: "")
            .replacingOccurrences(of: " - Wikipedia", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(cleanTitle) Champion"
    }

    private var classroomLessonBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    NovaPalette.classroomSky.opacity(0.26),
                    NovaPalette.classroomPaper,
                    NovaPalette.classroomPaper,
                    NovaPalette.classroomWood.opacity(0.28)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    classroomWindow
                        .frame(width: 154, height: 104)
                        .padding(.top, 36)
                        .padding(.leading, 44)

                    Spacer()

                    Circle()
                        .fill(NovaPalette.classroomSun.opacity(0.40))
                        .frame(width: 72, height: 72)
                        .overlay {
                            Circle()
                                .stroke(NovaPalette.classroomInk.opacity(0.14), lineWidth: 2)
                        }
                        .padding(.top, 44)
                        .padding(.trailing, 58)
                        .accessibilityHidden(true)
                }

                Spacer()

                VStack(spacing: 0) {
                    Rectangle()
                        .fill(NovaPalette.classroomWood.opacity(0.38))
                        .frame(height: 16)

                    LinearGradient(
                        colors: [
                            NovaPalette.classroomWood.opacity(0.48),
                            NovaPalette.classroomWood.opacity(0.24)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 136)
                }
                .accessibilityHidden(true)
            }

            Rectangle()
                .fill(NovaPalette.classroomSchoolRed.opacity(0.12))
                .frame(height: 6)
                .frame(maxHeight: .infinity, alignment: .top)
                .accessibilityHidden(true)
        }
    }

    private var classroomWindow: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(NovaPalette.classroomSky.opacity(0.36))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.22), lineWidth: 3)
            }
            .overlay {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(NovaPalette.classroomInk.opacity(0.18))
                        .frame(width: 3)
                }
            }
            .overlay {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(NovaPalette.classroomInk.opacity(0.18))
                        .frame(height: 3)
                }
            }
            .accessibilityHidden(true)
    }

    private func classroomCardStage<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(NovaPalette.classroomPaper.opacity(0.88))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(NovaPalette.classroomInk.opacity(0.28), lineWidth: 3)
                }
                .shadow(color: NovaPalette.classroomInk.opacity(0.12), radius: 10, x: 0, y: 6)

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(NovaPalette.classroomChalkboard.opacity(0.86))
                    .frame(height: 14)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.sm)

                Spacer()

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(NovaPalette.classroomWood.opacity(0.82))
                    .frame(height: 18)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.sm)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            content()
        }
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(NovaPalette.classroomSchoolRed.opacity(0.82))
                .frame(width: 18, height: 18)
                .overlay {
                    Circle()
                        .stroke(NovaPalette.classroomInk.opacity(0.36), lineWidth: 1.5)
                }
                .padding(Spacing.md)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(NovaPalette.classroomSun.opacity(0.72))
                .frame(width: 22, height: 22)
                .overlay {
                    Circle()
                        .stroke(NovaPalette.classroomInk.opacity(0.30), lineWidth: 1.5)
                }
                .padding(Spacing.md)
                .accessibilityHidden(true)
        }
    }

    /// Direction of a workbook nav-button page turn. Drives whether
    /// the chevron sits leading or trailing the title.
    private enum WorkbookNavDirection {
        case leading
        case trailing
    }

    /// Tone of a workbook nav button. Routine page turns use
    /// `.paper` (classroom-paper fill, school-red accent). The
    /// last-card Finish action uses `.finish` (sun-yellow sticker)
    /// so the lesson-complete moment stands out from the regular
    /// page-turn pair.
    private enum WorkbookNavTone {
        case paper
        case finish
    }

    /// Label content for a workbook page-turn button: a
    /// classroom-tokened pill with chevron + title that reads as a
    /// page tab in the workbook chrome rather than a generic
    /// comic-page button. Internal styling lives here so the two
    /// Prev/Next buttons stay consistent without exporting another
    /// shared button style.
    @ViewBuilder
    private func workbookPageTurnLabel(
        title: String,
        direction: WorkbookNavDirection,
        tone: WorkbookNavTone
    ) -> some View {
        let accent: Color = {
            switch tone {
            case .paper: return NovaPalette.classroomSchoolRed
            case .finish: return NovaPalette.classroomInk
            }
        }()
        let fill: Color = {
            switch tone {
            case .paper: return NovaPalette.classroomPaper
            case .finish: return NovaPalette.classroomSun
            }
        }()
        let chevronName = direction == .leading ? "chevron.left" : (tone == .finish ? "checkmark.circle.fill" : "chevron.right")

        HStack(spacing: 8) {
            if direction == .leading {
                Image(systemName: chevronName)
                    .font(.headline)
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(NovaPalette.smallHeadingFont().weight(.bold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if direction == .trailing {
                Image(systemName: chevronName)
                    .font(.headline)
                    .foregroundStyle(accent)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, Spacing.lg)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(NovaPalette.classroomInk.opacity(0.7), lineWidth: 2)
        )
        .shadow(color: NovaPalette.classroomInk.opacity(0.18), radius: 4, x: 0, y: 2)
    }

    /// Loading state styled as "today's lesson is being chalked onto the
    /// board". Three classroom-chalk lines + a yellow sticky note that
    /// reads "Setting up the lesson…". Static — no ungated motion.
    private var classroomLessonLoading: some View {
        VStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Capsule(style: .continuous)
                    .fill(NovaPalette.classroomChalkDust.opacity(0.7))
                    .frame(width: 168, height: 12)

                Capsule(style: .continuous)
                    .fill(NovaPalette.classroomChalkDust.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .frame(height: 10)

                Capsule(style: .continuous)
                    .fill(NovaPalette.classroomChalkDust.opacity(0.35))
                    .frame(maxWidth: 220)
                    .frame(height: 10)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                NovaPalette.classroomChalkboard,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.3), lineWidth: 2)
            )
            .accessibilityHidden(true)

            HStack(spacing: Spacing.sm) {
                Image(systemName: "pencil.tip")
                    .font(.headline)
                    .foregroundStyle(NovaPalette.classroomLeaf)
                    .accessibilityHidden(true)

                Text("Setting up the lesson…")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(NovaPalette.classroomInk)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                NovaPalette.classroomSun.opacity(0.32),
                in: Capsule(style: .continuous)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(NovaPalette.classroomSun.opacity(0.55), lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Setting up the lesson")
        }
    }

    /// Empty state styled as a blank chalkboard with a friendly note —
    /// "the teacher hasn't put any cards on the board yet". Preserves
    /// the meaning of the previous "No cards" message while staying
    /// in-world.
    private var classroomEmptyState: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(NovaPalette.classroomChalkboard.opacity(0.92))

                VStack(spacing: 6) {
                    Capsule(style: .continuous)
                        .fill(NovaPalette.classroomChalkDust.opacity(0.32))
                        .frame(width: 96, height: 4)

                    Capsule(style: .continuous)
                        .fill(NovaPalette.classroomChalkDust.opacity(0.22))
                        .frame(width: 64, height: 4)
                }
            }
            .frame(maxWidth: 240)
            .frame(height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.3), lineWidth: 2)
            )
            .accessibilityHidden(true)

            Text("This lesson is still being prepared")
                .font(NovaPalette.headingFont())
                .foregroundStyle(NovaPalette.classroomInk)
                .multilineTextAlignment(.center)

            Text("Check back soon — your teacher hasn’t put any cards on the board yet.")
                .font(NovaPalette.captionFont())
                .foregroundStyle(NovaPalette.classroomInk.opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, Spacing.lg)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This lesson has no cards yet. Check back soon.")
    }
}

#Preview {
    let lesson = Lesson(
        id: UUID(),
        pathId: UUID(),
        userId: UUID(),
        title: "What Makes AI Smart?",
        description: "Learn how artificial intelligence learns from data",
        thumbnailURL: nil,
        difficulty: 1,
        sourceURL: nil,
        aiAnalysis: nil,
        status: .published,
        sortOrder: 1,
        createdAt: Date(),
        publishedAt: Date(),
        cards: []
    )

    NavigationStack {
        FlipbookView(lesson: lesson)
    }
}
