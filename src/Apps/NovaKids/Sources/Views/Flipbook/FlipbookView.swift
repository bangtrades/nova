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
            NovaPalette.novaBackground
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

                Spacer()

                // S11-19: error banner surfaces fetch failures without
                // killing the card deck. Matches the Home / Lessons /
                // Trophy language — page fill + ink stroke + coral icon +
                // .novaSecondary() retry.
                if let error = viewModel.loadError {
                    errorBanner(message: error.errorDescription ?? "Something went wrong")
                        .padding(.horizontal, Spacing.lg)
                }

                // S11-19: skeleton while the cards endpoint is in flight.
                // Grid mode matches the mental shape of "a deck is on the
                // way" better than a spinner does.
                if viewModel.isLoading && viewModel.cards.isEmpty {
                    Spacer()
                    LoadingSkeletonView(itemCount: 3, isGrid: false)
                        .padding(Spacing.lg)
                    Spacer()
                }

                // Card display with TabView for swiping
                if !viewModel.cards.isEmpty {
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
                } else {
                    EmptyStateView(
                        title: "No cards",
                        subtitle: "This lesson has no content yet",
                        icon: "exclamationmark.circle"
                    )
                }

                Spacer()

                // Progress dots — S12-01 caps the dot row at 600pt so the
                // marker spread stays readable on iPad instead of 16 dots
                // walking from edge to edge of a 1366pt landscape.
                if !viewModel.cards.isEmpty {
                    CardProgressDots(
                        currentIndex: viewModel.currentCardIndex,
                        totalCards: viewModel.cards.count
                    )
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                }

                // Navigation buttons — S11-11 moved these onto the
                // shared `NovaSecondaryButtonStyle` so the prev / next pair
                // picks up the ink-outline / page-fill / coral-text comic
                // chrome. Two secondary buttons read cleanly here because
                // neither is a top-of-screen primary CTA — the primary
                // action is the card content itself.
                // S12-01 caps the Prev/Next pair at 600pt so the two
                // buttons don't land on opposite ends of an iPad landscape
                // viewport. Keeps them reading as a paired control rather
                // than two orphaned buttons.
                if !viewModel.cards.isEmpty {
                    HStack(spacing: Spacing.md) {
                        let isAtStart = viewModel.currentCardIndex == 0
                        let isAtEnd = viewModel.isLastCard

                        // Previous
                        Button {
                            // S11-16: card index transition animates under default,
                            // snaps instant under reduce-motion. The TabView page
                            // slide is ambient motion — progress dots + card
                            // content change both convey the navigation either way.
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                                viewModel.previousCard()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.headline)
                                    .accessibilityHidden(true)
                                Text("Previous")
                            }
                        }
                        .novaSecondary()
                        .disabled(isAtStart)
                        .opacity(isAtStart ? 0.5 : 1.0)
                        .accessibilityLabel("Previous card")

                        // Next / Finish
                        // S13: when isAtEnd, fire the lesson-complete flow
                        // (record + celebrate) instead of advancing the index.
                        // The previous shape disabled the button at the
                        // last card, which made the kid hit a dead end —
                        // they finished the quiz, tapped Finish, and
                        // nothing happened. Now Finish is always live and
                        // semantically correct.
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
                            HStack(spacing: 8) {
                                Text(isAtEnd ? "Finish" : "Next")
                                Image(
                                    systemName: isAtEnd
                                        ? "checkmark.circle.fill"
                                        : "chevron.right"
                                )
                                .font(.headline)
                                .accessibilityHidden(true)
                            }
                        }
                        .novaSecondary()
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
                Task { await viewModel.retryLoad() }
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
        .accessibilityLabel("Error loading cards: \(message)")
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
