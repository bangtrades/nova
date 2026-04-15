import SwiftUI

/// Math-based parental gate to prevent unauthorized access.
///
/// Displays a simple math problem that must be solved to grant temporary access.
/// Provides haptic feedback and regenerates on incorrect attempts.
public struct ParentalGateView: View {
    let onSuccess: () -> Void

    @State private var currentProblem: MathProblem = MathProblem.generateRandom()
    @State private var selectedAnswer: Int? = nil
    @State private var isShaking = false
    @State private var attempts = 0
    @State private var showSuccess = false
    @State private var isLockedOut = false
    @State private var lockoutSecondsRemaining = 0
    @State private var lockoutTask: Task<Void, Never>?
    @State private var dismissTask: Task<Void, Never>?

    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    /// Lockout after this many consecutive failures.
    private let maxAttemptsBeforeLockout = 3
    /// Lockout duration in seconds (doubles each time).
    private var lockoutDuration: Int {
        let multiplier = max(1, attempts / maxAttemptsBeforeLockout)
        return min(10 * multiplier, 60) // 10s, 20s, 30s... up to 60s
    }

    private struct MathProblem {
        let num1: Int
        let num2: Int
        let operation: Operation
        let answerChoices: [Int]

        enum Operation: CaseIterable {
            case add
            case subtract
            case multiply

            var symbol: String {
                switch self {
                case .add:
                    return "+"
                case .subtract:
                    return "−"
                case .multiply:
                    return "×"
                }
            }

            func calculate(_ a: Int, _ b: Int) -> Int {
                switch self {
                case .add:
                    return a + b
                case .subtract:
                    return a - b
                case .multiply:
                    return a * b
                }
            }
        }

        var correctAnswer: Int {
            operation.calculate(num1, num2)
        }

        static func generateRandom() -> MathProblem {
            let operation: Operation = Operation.allCases.randomElement()!

            let num1: Int
            let num2: Int

            switch operation {
            case .multiply:
                // Keep multiplication manageable (2-9 × 2-9)
                num1 = Int.random(in: 2...9)
                num2 = Int.random(in: 2...9)
            case .subtract:
                // Ensure positive result
                num1 = Int.random(in: 5...20)
                num2 = Int.random(in: 1...num1)
            case .add:
                num1 = Int.random(in: 3...15)
                num2 = Int.random(in: 3...15)
            }

            let correctAnswer = operation.calculate(num1, num2)
            var choices = [correctAnswer]

            // Generate 4 incorrect choices (5 total → 20% guess rate)
            while choices.count < 5 {
                let offset = Int.random(in: 1...8)
                let wrongAnswer = Bool.random() ? (correctAnswer + offset) : (correctAnswer - offset)
                if !choices.contains(wrongAnswer) && wrongAnswer >= 0 {
                    choices.append(wrongAnswer)
                }
            }

            return MathProblem(
                num1: num1,
                num2: num2,
                operation: operation,
                answerChoices: choices.shuffled()
            )
        }
    }

    public init(onSuccess: @escaping () -> Void) {
        self.onSuccess = onSuccess
    }

    public var body: some View {
        ZStack {
            NovaPalette.novaBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "lock.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(NovaPalette.novaPurple)

                    Text("Parent Check")
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(.primary)

                    Text("This helps us make sure a grown-up is here")
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 24)

                Spacer()

                // Math problem
                VStack(spacing: 24) {
                    // Problem display
                    HStack(spacing: 12) {
                        Text("\(currentProblem.num1)")
                            .font(NovaPalette.titleFont())
                            .foregroundStyle(NovaPalette.novaBlue)

                        Text(currentProblem.operation.symbol)
                            .font(NovaPalette.titleFont())
                            .foregroundStyle(.secondary)

                        Text("\(currentProblem.num2)")
                            .font(NovaPalette.titleFont())
                            .foregroundStyle(NovaPalette.novaBlue)

                        Text("=")
                            .font(NovaPalette.titleFont())
                            .foregroundStyle(.secondary)

                        Text("?")
                            .font(NovaPalette.titleFont())
                            .foregroundStyle(NovaPalette.novaOrange)
                    }
                    .padding(24)
                    .background(NovaPalette.novaCardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .offset(x: isShaking ? CGFloat.random(in: -5...5) : 0)
                    .animation(reduceMotion ? .none : .easeInOut(duration: 0.05), value: isShaking)

                    // Answer buttons
                    VStack(spacing: 12) {
                        Text("What's the answer?")
                            .font(NovaPalette.bodyFont())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 12) {
                            ForEach(currentProblem.answerChoices.indices, id: \.self) { index in
                                let answer = currentProblem.answerChoices[index]
                                AnswerButton(
                                    answer: answer,
                                    isSelected: selectedAnswer == answer,
                                    isCorrect: selectedAnswer == answer && answer == currentProblem.correctAnswer,
                                    isWrong: selectedAnswer == answer && answer != currentProblem.correctAnswer,
                                    onTap: { handleAnswerTap(answer: answer) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Lockout or attempt counter
                if isLockedOut {
                    VStack(spacing: 8) {
                        Text("Too many tries")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Try again in \(lockoutSecondsRemaining)s")
                            .font(.caption)
                            .foregroundStyle(NovaPalette.novaOrange)
                    }
                } else {
                    Text("Attempts: \(attempts)")
                        .font(NovaPalette.captionFont())
                        .foregroundStyle(.secondary)
                }

                // Success message
                if showSuccess {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(NovaPalette.novaGreen)

                        Text("Verified!")
                            .font(NovaPalette.bodyFont())
                            .foregroundStyle(NovaPalette.novaGreen)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 32)
            .onDisappear {
                lockoutTask?.cancel()
                dismissTask?.cancel()
            }
        }
    }

    private func handleAnswerTap(answer: Int) {
        guard selectedAnswer == nil, !isLockedOut else { return }

        selectedAnswer = answer
        attempts += 1

        if answer == currentProblem.correctAnswer {
            // Correct answer
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.4)) {
                showSuccess = true
            }

            // Haptic success
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()

            // Dismiss and trigger callback after delay
            dismissTask = Task {
                try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
                guard !Task.isCancelled else { return }
                dismiss()
                onSuccess()
            }
        } else {
            // Wrong answer - shake and reset
            let impact = UIImpactFeedbackGenerator(style: .rigid)
            impact.impactOccurred()

            // Check for lockout
            if attempts % maxAttemptsBeforeLockout == 0 {
                triggerLockout()
                return
            }

            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isShaking = true
                }
            }

            dismissTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                guard !Task.isCancelled else { return }
                if !reduceMotion {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isShaking = false
                    }
                }
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                guard !Task.isCancelled else { return }
                currentProblem = MathProblem.generateRandom()
                selectedAnswer = nil
            }
        }
    }

    private func triggerLockout() {
        isLockedOut = true
        lockoutSecondsRemaining = lockoutDuration
        selectedAnswer = nil

        lockoutTask = Task {
            while lockoutSecondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                lockoutSecondsRemaining -= 1
            }
            isLockedOut = false
            isShaking = false
            currentProblem = MathProblem.generateRandom()
        }
    }
}

/// Individual answer button.
private struct AnswerButton: View {
    let answer: Int
    let isSelected: Bool
    let isCorrect: Bool
    let isWrong: Bool
    let onTap: () -> Void

    var backgroundColor: Color {
        if isCorrect {
            return NovaPalette.novaGreen
        } else if isWrong {
            return NovaPalette.novaOrange
        } else if isSelected {
            return NovaPalette.novaBlue
        } else {
            return NovaPalette.novaBlue.opacity(0.1)
        }
    }

    var textColor: Color {
        if isSelected {
            return .white
        }
        return .primary
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                } else if isWrong {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                Text("\(answer)")
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(textColor)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(backgroundColor)
            .cornerRadius(12)
        }
        .disabled(isSelected)
        .opacity((isWrong && !isSelected) ? 0.5 : 1.0)
        .accessibilityLabel("Answer: \(answer)")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    ParentalGateView(onSuccess: {
        print("Parent verified!")
    })
}
