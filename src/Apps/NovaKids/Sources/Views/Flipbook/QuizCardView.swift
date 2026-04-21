import SwiftUI
import NovaCore

/// Multiple-choice quiz card with immediate feedback.
///
/// Shows question and answer options. Provides haptic feedback and animations
/// for correct/incorrect responses. Allows retries with hint after 3 attempts.
public struct QuizCardView: View {
    /// The card to display.
    let card: Card

    @State private var selectedOptionId: String? = nil
    @State private var isCorrect: Bool? = nil
    @State private var attempts: Int = 0
    @State private var showHint: Bool = false
    @State private var showSuccess: Bool = false
    @State private var successScale: Double = 0.8
    @State private var feedbackMessage: String = ""
    @State private var feedbackOpacity: Double = 0
    @State private var celebrateTask: Task<Void, Never>?
    @State private var hintTask: Task<Void, Never>?
    @State private var retryTask: Task<Void, Never>?

    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorScheme) var colorScheme

    private let maxAttempts = 3
    private var correctOptionId: String? {
        guard let index = card.content.correctOptionIndex,
              let options = card.content.options,
              index >= 0 && index < options.count
        else { return nil }
        return options[index].id
    }

    public init(card: Card) {
        self.card = card
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    NovaPalette.novaBlue.opacity(0.1),
                    NovaPalette.novaPurple.opacity(0.1),
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    if let title = card.content.title {
                        Text(title)
                            .font(NovaPalette.headingFont())
                            .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)

                // Question
                VStack(alignment: .leading, spacing: 12) {
                    if let question = card.content.question {
                        Text(question)
                            .font(NovaPalette.headingFont())
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)

                Spacer(minLength: 24)

                // Answer options
                if let options = card.content.options {
                    VStack(spacing: 12) {
                        ForEach(options) { option in
                            QuizOptionButton(
                                option: option,
                                isSelected: selectedOptionId == option.id,
                                isCorrect: isCorrect,
                                correctOptionId: correctOptionId,
                                onTap: { handleOptionTap(option: option) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 24)

                // Feedback section
                if let isCorrect = isCorrect {
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(isCorrect ? NovaPalette.novaGreen : NovaPalette.novaOrange)
                                .accessibilityHidden(true)

                            Text(feedbackMessage)
                                .font(NovaPalette.largeBodyFont())
                                .foregroundStyle(.primary)

                            Spacer()
                        }
                        .padding(16)
                        .background(
                            isCorrect
                                ? NovaPalette.novaGreen.opacity(0.1)
                                : NovaPalette.novaOrange.opacity(0.1)
                        )
                        .cornerRadius(12)

                        if showHint && !isCorrect {
                            if let hint = card.interactionConfig?.hintMessage {
                                Text(hint)
                                    .font(NovaPalette.bodyFont())
                                    .foregroundStyle(.secondary)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(NovaPalette.novaYellow.opacity(0.25))
                                    )
                                    .cornerRadius(8)
                            }
                        }

                        if isCorrect {
                            Button(action: {
                                dismiss()
                            }) {
                                HStack {
                                    Text("Next →")
                                        .fontWeight(.semibold)
                                    Image(systemName: "chevron.right")
                                        .accessibilityHidden(true)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(NovaPalette.novaGreen)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                            }
                        } else if attempts >= maxAttempts && !isCorrect {
                            Button(action: {
                                resetQuiz()
                            }) {
                                Text("Try Again")
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(NovaPalette.novaOrange)
                                    .foregroundStyle(.white)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 20)

                // Attempt counter
                VStack(spacing: 8) {
                    HStack {
                        Text("Attempts: \(attempts)/\(maxAttempts)")
                            .font(NovaPalette.bodyFont())
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Attempt dots
                        HStack(spacing: 6) {
                            ForEach(1...maxAttempts, id: \.self) { i in
                                Circle()
                                    .fill(i <= attempts ? NovaPalette.novaOrange : NovaPalette.ink.opacity(0.2))
                                    .frame(width: 8, height: 8)
                                    .accessibilityHidden(true)
                            }
                        }
                        .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }

            // Success celebration
            if showSuccess {
                VStack {
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "star.fill")
                            .font(.largeTitle)
                            .foregroundStyle(NovaPalette.novaYellow)
                            .accessibilityHidden(true)

                        Text("Correct!")
                            .font(NovaPalette.headingFont())
                            .foregroundStyle(.primary)

                        Text("You got it right! 🎉")
                            .font(NovaPalette.bodyFont())
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(NovaPalette.novaCardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(20)
                    .scaleEffect(successScale)

                    Spacer()
                }
                .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }
        }
        .onAppear {
            setupInitialState()
        }
        .onDisappear {
            celebrateTask?.cancel()
            hintTask?.cancel()
            retryTask?.cancel()
        }
    }

    private func setupInitialState() {
        feedbackMessage = ""
        feedbackOpacity = 0
        attempts = 0
        isCorrect = nil
        selectedOptionId = nil
    }

    private func handleOptionTap(option: Card.QuizOption) {
        guard isCorrect == nil else { return }

        selectedOptionId = option.id
        attempts += 1

        let isCorrectAnswer = option.id == correctOptionId

        if isCorrectAnswer {
            celebrateCorrect()
        } else {
            handleIncorrect()
        }
    }

    private func celebrateCorrect() {
        isCorrect = true
        feedbackMessage = "Correct!"

        withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.4)) {
            feedbackOpacity = 1.0
            showSuccess = true
            successScale = 1.0
        }

        // Haptic success
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        // Auto-advance after 2 seconds
        celebrateTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    private func handleIncorrect() {
        isCorrect = false
        feedbackMessage = "Try again!"

        withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.3)) {
            feedbackOpacity = 1.0
        }

        // Gentle warning haptic
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        // Check if should show hint
        if attempts >= maxAttempts - 1 {
            hintTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                withAnimation {
                    showHint = true
                }
            }
        }

        // Reset for retry after 1 second
        retryTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            if attempts < maxAttempts {
                resetForRetry()
            }
        }
    }

    private func resetForRetry() {
        withAnimation(reduceMotion ? .none : .default) {
            selectedOptionId = nil
            isCorrect = nil
            feedbackMessage = ""
            feedbackOpacity = 0
        }
    }

    private func resetQuiz() {
        attempts = 0
        selectedOptionId = nil
        isCorrect = nil
        feedbackMessage = ""
        feedbackOpacity = 0
        showHint = false
        showSuccess = false
    }
}

/// Individual quiz option button.
private struct QuizOptionButton: View {
    let option: Card.QuizOption
    let isSelected: Bool
    let isCorrect: Bool?
    let correctOptionId: String?
    let onTap: () -> Void

    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var buttonColor: Color {
        if !isSelected && (isCorrect == nil) {
            return NovaPalette.novaBlue.opacity(0.1)
        }

        if isSelected {
            if isCorrect == true {
                return NovaPalette.novaGreen
            } else {
                return NovaPalette.novaOrange
            }
        }

        // Highlight correct answer if shown
        if isCorrect == false && option.id == correctOptionId {
            return NovaPalette.novaGreen.opacity(0.2)
        }

        return NovaPalette.ink.opacity(0.05)
    }

    var textColor: Color {
        if isSelected && (isCorrect == true || isCorrect == false) {
            return .white
        }
        return .primary
    }

    var body: some View {
        Button(action: {
            if isCorrect == nil {
                onTap()
            }
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))

                    if isSelected && isCorrect == true {
                        Image(systemName: "checkmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                    } else if isSelected && isCorrect == false {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                    } else if option.id == correctOptionId && isCorrect == false {
                        Image(systemName: "checkmark")
                            .font(.headline)
                            .foregroundStyle(NovaPalette.novaGreen)
                            .accessibilityHidden(true)
                    } else {
                        Circle()
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 2)
                            )
                            .foregroundStyle(.gray.opacity(0.3))
                    }
                }
                .frame(width: 36, height: 36)

                // Option text
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.text)
                        .font(NovaPalette.largeBodyFont())
                        .fontWeight(.semibold)
                        .foregroundStyle(textColor)
                        .lineLimit(2)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(buttonColor)
            .cornerRadius(12)
        }
        .disabled(isCorrect != nil)
        .opacity(isCorrect == false && option.id != correctOptionId && !isSelected ? 0.5 : 1.0)
        .scaleEffect(reduceMotion ? 1.0 : (isPressed ? 0.97 : 1.0))
        .onLongPressGesture(minimumDuration: 0.01, perform: {}) { pressing in
            if !pressing && isCorrect == nil {
                isPressed = false
            } else if isCorrect == nil {
                isPressed = pressing
            }
        }
        .accessibilityLabel("Option: \(option.text)")
        .accessibilityHint("Double tap to select this answer")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            // Ensure VoiceOver activation triggers the tap handler
            onTap()
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
}
