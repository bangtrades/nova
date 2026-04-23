import SwiftUI
import NovaCore

/// Single answer tile for `QuizCardView` (S11-06).
///
/// The tile swaps its visual language based on the quiz's lifecycle state:
///
/// - **Idle** (`evaluation == nil`, not the selected option) — uses
///   `NovaSecondaryButtonStyle`: page fill, ink outline, coral text. This
///   reads as "an available choice".
/// - **Selected, awaiting eval** — flips to `NovaPrimaryButtonStyle`: coral
///   fill, ink outline. Visual commitment, matched by the medium haptic the
///   primary style fires on press.
/// - **Correct** (selected and `evaluation == .correct`) — green fill with
///   check glyph.
/// - **Incorrect** (selected and `evaluation == .incorrect`) — orange fill
///   with cross glyph. The non-selected options dim to 0.5 opacity.
/// - **Shown as the right answer** (unselected, but the quiz settled on
///   `.incorrect`) — a soft green outline + check glyph so the kid can see
///   what the correct answer was without being penalized for not picking it.
///
/// The state-driven rendering replaces the old `buttonColor` / `textColor`
/// computed-maze pattern — semantic states are easier to reason about than
/// a 4-way color decision tree, and they map 1:1 to the quiz view's state
/// machine.
///
/// ## Tap handling
///
/// The button calls `onTap` only when `evaluation == nil`. Once the quiz has
/// evaluated an answer, the buttons are fully disabled via `.disabled(true)`
/// so VoiceOver also reports them as unavailable — the parent view owns
/// the retry flow.
struct QuizAnswerButton: View {
    let option: Card.QuizOption

    /// Whether this specific option is the one the user selected. Drives the
    /// primary/secondary style swap.
    let isSelected: Bool

    /// Current evaluation state of the quiz. `nil` until the user picks an
    /// answer; non-nil values drive the correct/incorrect visual treatment.
    let evaluation: QuizEvaluation?

    /// Whether this option is the actual correct answer. Used to highlight
    /// the right answer after the user picks wrong.
    let isCorrectAnswer: Bool

    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Semantic state at the moment of render. Computing once here keeps the
    /// body light and makes the visual decisions obvious in one place.
    private var state: AnswerState {
        switch evaluation {
        case .none:
            return isSelected ? .committed : .idle
        case .correct where isSelected:
            return .correct
        case .incorrect where isSelected:
            return .incorrect
        case .incorrect where isCorrectAnswer:
            return .revealedAsCorrect
        default:
            return .dimmed
        }
    }

    var body: some View {
        Button {
            guard evaluation == nil else { return }
            onTap()
        } label: {
            HStack(spacing: Spacing.md) {
                Text(option.text)
                    .font(NovaPalette.bodyFont().weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                Spacer(minLength: Spacing.sm)

                statusGlyph
            }
        }
        .buttonStyle(AnswerTileStyle(state: state))
        .disabled(evaluation != nil)
        .accessibilityLabel(option.text)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(evaluation == nil ? "Double tap to pick this answer" : "")
        .accessibilityAddTraits(.isButton)
    }

    /// Trailing glyph that makes correctness legible at a glance. VoiceOver
    /// users get the same information via `accessibilityValue`, so the glyph
    /// is marked hidden.
    @ViewBuilder
    private var statusGlyph: some View {
        switch state {
        case .correct:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        case .incorrect:
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .accessibilityHidden(true)
        case .revealedAsCorrect:
            Image(systemName: "checkmark.circle")
                .font(.title3)
                .foregroundStyle(NovaPalette.Category.green)
                .accessibilityHidden(true)
        case .idle, .committed, .dimmed:
            EmptyView()
        }
    }

    /// VoiceOver value string. Mirrors what the visual glyph signals so
    /// assistive-tech users receive parity feedback.
    private var accessibilityValue: String {
        switch state {
        case .idle: return ""
        case .committed: return "selected"
        case .correct: return "correct"
        case .incorrect: return "incorrect"
        case .revealedAsCorrect: return "correct answer"
        case .dimmed: return ""
        }
    }
}

// MARK: - Semantic state

/// Lifecycle outcome of the quiz's current evaluation cycle.
///
/// Kept as a dedicated enum (rather than an `isCorrect: Bool?` triple) because
/// the quiz view machines on two distinct concepts — whether the user has
/// answered, and whether their answer was right — and combining them into
/// a single optional made every call site read `isCorrect == nil` as "not
/// yet answered", which obscured intent.
enum QuizEvaluation: Equatable {
    case correct
    case incorrect
}

/// Internal rendering state of one answer tile. Computed from the quiz's
/// `QuizEvaluation` plus per-option `isSelected` / `isCorrectAnswer` flags.
private enum AnswerState {
    /// Pre-evaluation, not selected. Uses secondary style.
    case idle
    /// Pre-evaluation, selected. Uses primary style.
    case committed
    /// Post-evaluation, selected, and right.
    case correct
    /// Post-evaluation, selected, and wrong.
    case incorrect
    /// Post-evaluation, not selected, but is the right answer (shown to
    /// teach the kid what they should've picked).
    case revealedAsCorrect
    /// Post-evaluation, not selected, not the right answer. Dimmed out.
    case dimmed
}

// MARK: - ButtonStyle

/// `ButtonStyle` whose makeBody switches on the semantic answer state.
///
/// Routing the render through a `ButtonStyle` rather than an inline
/// `Button { ... } label: { ... }` gives us `configuration.isPressed` for
/// free — the press-scale behavior that the old `QuizOptionButton` hand-rolled
/// with `onLongPressGesture(minimumDuration: 0.01)` now comes from the same
/// source as every other Nova button.
///
/// The style deliberately shares visual DNA with `NovaPrimaryButtonStyle` /
/// `NovaSecondaryButtonStyle` (2pt ink stroke, 16pt corner, 0.96 press scale,
/// spring animation) so a quiz answer tile reads as part of the same button
/// family — not a separate component.
private struct AnswerTileStyle: ButtonStyle {
    let state: AnswerState

    private let cornerRadius: CGFloat = 16
    private let pressedScale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.md)
            .padding(.horizontal, Spacing.md)
            .background(
                fill,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(NovaPalette.ink, lineWidth: 2)
            }
            .opacity(state == .dimmed ? 0.5 : 1.0)
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }

    /// Background fill per state. Uses the category palette for correct /
    /// incorrect moments so the signal is unambiguous.
    private var fill: Color {
        switch state {
        case .idle, .dimmed: return NovaPalette.page
        case .committed: return NovaPalette.coral
        case .correct: return NovaPalette.Category.green
        case .incorrect: return NovaPalette.Category.orange
        case .revealedAsCorrect: return NovaPalette.Category.green.opacity(0.15)
        }
    }

    /// Foreground text color per state. White on committed / correct /
    /// incorrect (so the 2pt ink stroke isn't competing with text tone),
    /// ink on idle / dimmed / revealed (so the text reads as "part of the
    /// page" rather than a committed action).
    private var foreground: Color {
        switch state {
        case .idle, .dimmed, .revealedAsCorrect: return NovaPalette.ink
        case .committed, .correct, .incorrect: return NovaPalette.page
        }
    }
}

#Preview("Answer states") {
    let opt = Card.QuizOption(id: "a", text: "A sample answer option")

    return VStack(spacing: Spacing.sm) {
        QuizAnswerButton(option: opt, isSelected: false, evaluation: nil,       isCorrectAnswer: false) { }
        QuizAnswerButton(option: opt, isSelected: true,  evaluation: nil,       isCorrectAnswer: true)  { }
        QuizAnswerButton(option: opt, isSelected: true,  evaluation: .correct,  isCorrectAnswer: true)  { }
        QuizAnswerButton(option: opt, isSelected: true,  evaluation: .incorrect, isCorrectAnswer: false) { }
        QuizAnswerButton(option: opt, isSelected: false, evaluation: .incorrect, isCorrectAnswer: true)  { }
        QuizAnswerButton(option: opt, isSelected: false, evaluation: .incorrect, isCorrectAnswer: false) { }
    }
    .padding(Spacing.lg)
    .background(NovaPalette.novaBackground)
}
