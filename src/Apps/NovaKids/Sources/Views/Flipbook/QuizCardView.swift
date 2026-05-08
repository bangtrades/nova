import SwiftUI
import NovaCore
import UIKit

/// Multiple-choice quiz card composed through the S11 design system.
///
/// The quiz lives inside a `FlipbookView` page (`TabView` with page style),
/// so this view is content-only — no full-screen backgrounds, no safe-area
/// treatment, no internal navigation. Its job is: show the question, show the
/// options, give the kid immediate feedback on each tap, and celebrate
/// correctness with a POW burst so the "I got it right!" beat lands hard.
///
/// ## State machine
///
/// The quiz cycles through four stages:
///
/// 1. **Idle** — no selection yet. All options use `NovaSecondaryButtonStyle`.
///    Attempts counter shows 0 of max.
/// 2. **Evaluating** — the user tapped an option. The option flips to the
///    primary style; within the next frame we resolve correct vs incorrect.
/// 3. **Correct** — POW reaction fires, success haptic fires, feedback pill
///    shows "Correct!", and a `Next` button appears. No auto-dismiss — the
///    user owns when to move on (flipping the auto-dismiss bug the previous
///    version carried).
/// 4. **Incorrect** — wrong haptic fires, the retry cycle reset-arms after
///    1s so the kid can try again. Hint surfaces at `maxAttempts - 1`. After
///    `maxAttempts` the Try Again button appears and the attempt counter
///    resets on tap.
///
/// Each stage is explicitly represented by `QuizEvaluation?` (nil = idle or
/// evaluating) plus the `attempts` counter. Replaces the previous
/// `isCorrect: Bool?` triple which overloaded nil to mean both "idle" and
/// "evaluating" — unambiguous state makes the code easier to audit.
///
/// ## Optional completion hook
///
/// `onCorrect` fires once the POW burst plays out, in case a parent view
/// wants to advance the flipbook or mark progress. The default is `nil` so
/// the user's swipe-to-next-card cadence is preserved. **Do not call
/// `dismiss()` from here** — at quiz-card depth the environment's dismiss
/// pops the entire FlipbookView, which would eject the kid from the lesson
/// the moment they answer correctly. That was a latent bug in the previous
/// version; the fix is to keep the view dumb about navigation and let
/// callers opt in.
public struct QuizCardView: View {
    /// The card to display.
    let card: Card

    /// Optional callback fired after the POW burst completes on a correct
    /// answer. Parent views can use this to advance the flipbook or mark
    /// the card as "answered correctly". Leave nil to keep the quiz
    /// self-contained (the default behavior).
    var onCorrect: (() -> Void)?

    // MARK: - State

    @State private var selectedOptionId: String? = nil
    @State private var evaluation: QuizEvaluation? = nil
    @State private var attempts: Int = 0
    @State private var showHint: Bool = false
    @State private var showPow: Bool = false

    // Structured-concurrency handles so the retry / hint / celebrate cycles
    // cancel cleanly when the view disappears (user swipes to another card).
    @State private var celebrateTask: Task<Void, Never>?
    @State private var hintTask: Task<Void, Never>?
    @State private var retryTask: Task<Void, Never>?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Tight ceiling on attempts before the hint surfaces and the kid is
    /// offered a reset. Three tries is Duolingo's default and strikes a
    /// balance between "try again" and "let's move on".
    private let maxAttempts = 3

    /// The `id` of the correct answer option, derived from
    /// `card.content.correctOptionIndex`. Returns nil if the card is
    /// malformed (index out of range, no options, etc.) — in which case
    /// the tile render treats every answer as wrong and the attempts counter
    /// will bottom out. That's a content bug the authoring pipeline should
    /// catch; this view fails soft rather than crashing.
    private var correctOptionId: String? {
        guard let index = card.content.correctOptionIndex,
              let options = card.content.options,
              index >= 0 && index < options.count
        else { return nil }
        return options[index].id
    }

    public init(card: Card, onCorrect: (() -> Void)? = nil) {
        self.card = card
        self.onCorrect = onCorrect
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            ChalkboardLessonCardSurface(cardKind: .quiz, title: cardTitle) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    question
                    answerList
                    feedbackBlock
                    attemptMeter
                }
            }
            .padding(.horizontal, Spacing.md)
            .overlay {
                // The POW burst floats above the card so it can extend past
                // the card's rounded edge for maximum kinetic effect. The
                // `allowsHitTesting(false)` keeps it from swallowing taps on
                // the Next button while it's animating out.
                QuizPowReaction(isActive: $showPow)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: showPow) { _, newValue in
            // When the burst fades (showPow flips back to false), let the
            // parent know a correct answer finished playing out. Nil-safe.
            if newValue == false && evaluation == .correct {
                onCorrect?()
            }
        }
        .onDisappear {
            celebrateTask?.cancel()
            hintTask?.cancel()
            retryTask?.cancel()
        }
    }

    // MARK: - Subviews

    private var cardTitle: String {
        if let title = card.content.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           title.isEmpty == false {
            return title
        }

        return "Quiz"
    }

    /// Question text rendered as a pinned/sticky prompt against the
    /// classroom-board surface. Yellow sticky-note treatment so the question
    /// reads as the kid's primary thing-to-do above the magnetic answer tiles.
    @ViewBuilder
    private var question: some View {
        if let questionText = card.content.question {
            Text(questionText)
                .font(NovaPalette.headingFont())
                .foregroundStyle(NovaPalette.classroomInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.md)
                .background(
                    NovaPalette.classroomSun.opacity(0.32),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(NovaPalette.classroomSun.opacity(0.55), lineWidth: 2)
                )
        }
    }

    /// Vertically-stacked answer tiles wrapped in a workbook tray so the
    /// row reads as classroom magnetic-tile manipulatives rather than a
    /// plain button list. The tray uses
    /// `LessonArtSlot.quizAnswerTilesTray` (canonical:
    /// `lesson_quiz_answer_tiles_45`; legacy:
    /// `lesson_answer_tiles_45_landscape`) as a painted backdrop when
    /// the asset is available; falls back to a paper-tinted rounded
    /// rectangle with ink stroke when not. Empty if the card has no
    /// options — we don't show a placeholder because a malformed quiz
    /// card is a content-pipeline bug, not a UX state the view should
    /// paper over.
    @ViewBuilder
    private var answerList: some View {
        if let options = card.content.options {
            VStack(spacing: Spacing.sm) {
                ForEach(options) { option in
                    QuizAnswerButton(
                        option: option,
                        isSelected: selectedOptionId == option.id,
                        evaluation: evaluation,
                        isCorrectAnswer: option.id == correctOptionId,
                        onTap: { handleOptionTap(option: option) }
                    )
                }
            }
            .padding(Spacing.md)
            .background(answerTrayBackground)
            .overlay {
                if LessonArtSlot.quizAnswerTilesTray.hasAsset == false {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(NovaPalette.classroomInk.opacity(0.20), lineWidth: 1.5)
                }
            }
        }
    }

    @ViewBuilder
    private var answerTrayBackground: some View {
        if let asset = LessonArtSlot.quizAnswerTilesTray.resolvedName {
            Image(asset)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(NovaPalette.classroomPaper.opacity(0.55))
        }
    }

    /// Feedback pill + hint + action button. The block collapses entirely
    /// when evaluation is nil, so the card doesn't reserve empty space
    /// before the user has engaged.
    @ViewBuilder
    private var feedbackBlock: some View {
        if let evaluation {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                feedbackPill(for: evaluation)

                if evaluation == .incorrect, showHint, let hint = card.interactionConfig?.hintMessage {
                    hintPill(text: hint)
                }

                actionButton(for: evaluation)
            }
            .transition(.opacity)
        }
    }

    /// The "Correct!" / "Try again!" pill. Uses category fills tinted low
    /// so the ink stroke on the tile above reads as the stronger signal.
    private func feedbackPill(for evaluation: QuizEvaluation) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: evaluation == .correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(evaluation == .correct ? NovaPalette.Category.green : NovaPalette.Category.orange)
                .accessibilityHidden(true)

            Text(evaluation == .correct ? "Correct!" : "Try again!")
                .font(NovaPalette.bodyFont().weight(.semibold))
                .foregroundStyle(NovaPalette.ink)

            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(
            (evaluation == .correct ? NovaPalette.Category.green : NovaPalette.Category.orange).opacity(0.15),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    /// Hint pill — shows only after the penultimate attempt fails,
    /// giving the kid one chance to retry with context before the
    /// final strike. Renders on top of the painted hint-note asset
    /// resolved through `LessonArtSlot.quizHintNote` (canonical:
    /// `lesson_quiz_hint_note_45`; legacy: `lesson_hint_note_45`)
    /// when present so the hint reads as a classroom sticky note
    /// pinned next to the answer tray; falls back to a sun-tinted
    /// rounded rectangle when the asset is absent.
    private func hintPill(text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(.subheadline)
                .foregroundStyle(NovaPalette.classroomSchoolRed)
                .accessibilityHidden(true)

            Text(text)
                .font(NovaPalette.bodyFont())
                .foregroundStyle(NovaPalette.classroomInk)

            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(hintNoteBackground)
        .accessibilityLabel("Hint: \(text)")
    }

    @ViewBuilder
    private var hintNoteBackground: some View {
        if let asset = LessonArtSlot.quizHintNote.resolvedName {
            Image(asset)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NovaPalette.classroomSun.opacity(0.32))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(NovaPalette.classroomSun.opacity(0.55), lineWidth: 2)
                )
        }
    }

    /// Post-evaluation action button: Next on correct, Try Again on
    /// exhausted-and-still-wrong, nothing during mid-cycle retries (because
    /// `resetForRetry()` will fire automatically). Uses the primary style
    /// so the button inherits the press-scale, haptic, and visual language
    /// the rest of the app uses for committed actions.
    @ViewBuilder
    private func actionButton(for evaluation: QuizEvaluation) -> some View {
        switch evaluation {
        case .correct:
            Button {
                onCorrect?()
            } label: {
                HStack {
                    Text("Next")
                    Image(systemName: "arrow.right")
                        .accessibilityHidden(true)
                }
            }
            .novaPrimary()
        case .incorrect where attempts >= maxAttempts:
            Button("Try Again") {
                resetQuiz()
            }
            .novaPrimary()
        default:
            EmptyView()
        }
    }

    /// Attempts counter + dot row. Dots are marked hidden from VoiceOver
    /// because the "Attempts: 1 of 3" label already communicates progress.
    private var attemptMeter: some View {
        HStack {
            Text("Attempts: \(attempts) of \(maxAttempts)")
                .font(NovaPalette.captionFont())
                .foregroundStyle(NovaPalette.ink.opacity(0.6))

            Spacer()

            HStack(spacing: Spacing.xs + 2) {
                ForEach(1...maxAttempts, id: \.self) { index in
                    Circle()
                        .fill(index <= attempts ? NovaPalette.Category.orange : NovaPalette.ink.opacity(0.15))
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - Interaction

    private func handleOptionTap(option: Card.QuizOption) {
        // Guard against taps after evaluation has been set — the button style
        // already disables the tile, but this belt-and-suspenders defends
        // against rapid double-taps racing the state update.
        guard evaluation == nil else { return }

        selectedOptionId = option.id
        attempts += 1
        NovaHaptics.commit()

        let isRight = option.id == correctOptionId
        if isRight {
            celebrateCorrect()
        } else {
            handleIncorrect()
        }
    }

    private func celebrateCorrect() {
        withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.25)) {
            evaluation = .correct
        }

        NovaHaptics.success()

        // Fire the POW burst on the next frame so SwiftUI renders the new
        // evaluation state before the animation kicks in — otherwise the
        // burst can start before the tile has flipped to green and the
        // two beats land out of sync.
        celebrateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard Task.isCancelled == false else { return }
            showPow = true
        }
    }

    private func handleIncorrect() {
        withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
            evaluation = .incorrect
        }

        NovaHaptics.wrong()

        // Show the hint one attempt before the cap so the kid gets a nudge
        // before they burn their last try.
        if attempts >= maxAttempts - 1 {
            hintTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard Task.isCancelled == false else { return }
                withAnimation(reduceMotion ? .none : .easeIn(duration: 0.25)) {
                    showHint = true
                }
            }
        }

        // Re-arm for a retry after 1s if we haven't hit the cap. At the cap
        // we leave the state as .incorrect so the Try Again button shows.
        if attempts < maxAttempts {
            retryTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard Task.isCancelled == false else { return }
                resetForRetry()
            }
        }
    }

    private func resetForRetry() {
        withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
            selectedOptionId = nil
            evaluation = nil
        }
    }

    private func resetQuiz() {
        withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.25)) {
            attempts = 0
            selectedOptionId = nil
            evaluation = nil
            showHint = false
            showPow = false
        }
    }
}

#Preview {
    let card = Card(
        id: UUID(),
        lessonId: UUID(),
        type: .quiz,
        sortOrder: 0,
        content: Card.CardContent(
            title: "Quiz",
            question: "What is machine learning?",
            options: [
                Card.QuizOption(id: "a", text: "When computers learn from data"),
                Card.QuizOption(id: "b", text: "A type of programming language"),
                Card.QuizOption(id: "c", text: "A video game"),
                Card.QuizOption(id: "d", text: "A learning app"),
            ],
            correctOptionIndex: 0
        ),
        interactionConfig: Card.InteractionConfig(
            hintMessage: "Think about how computers can improve by seeing more examples!"
        )
    )

    return QuizCardView(card: card)
        .padding(.vertical, Spacing.lg)
        .background(NovaPalette.novaBackground)
}
