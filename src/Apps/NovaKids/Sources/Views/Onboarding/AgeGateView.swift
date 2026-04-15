import SwiftUI

/// Age verification screen shown on initial launch (before onboarding).
///
/// Kid must confirm their birth year, then parent must enter their birth year to verify they're 18+.
/// Once passed, stored via @AppStorage("hasPassedAgeGate") with no way to bypass.
/// COPPA-compliant design.
public struct AgeGateView: View {
    @AppStorage("hasPassedAgeGate") var hasPassedAgeGate = false

    @State private var childBirthYear: Int = Calendar.current.component(.year, from: Date()) - 6
    @State private var parentBirthYear: Int = Calendar.current.component(.year, from: Date()) - 30
    @State private var stage: AgeGateStage = .childAge
    @State private var errorMessage: String?

    private let minChildYear = Calendar.current.component(.year, from: Date()) - 18
    private let maxChildYear = Calendar.current.component(.year, from: Date()) - 3

    public init() {}

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

                    Text("Getting Started")
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(.primary)

                    Text("A grown-up needs to help you get started!")
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 24)

                Spacer()

                // Content based on stage
                if stage == .childAge {
                    childAgePicker()
                } else {
                    parentVerification()
                }

                Spacer()

                // Error message
                if let error = errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(NovaPalette.novaPink)

                        Text(error)
                            .font(NovaPalette.bodyFont())
                            .foregroundStyle(NovaPalette.novaPink)
                            .multilineTextAlignment(.center)
                    }
                    .padding(16)
                    .background(NovaPalette.novaPink.opacity(0.15))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                Spacer()
            }
            .padding(.vertical, 32)
        }
    }

    // MARK: - Child Age Stage

    private func childAgePicker() -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("What year were you born?")
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)

                Picker("Birth Year", selection: $childBirthYear) {
                    ForEach(minChildYear...maxChildYear, id: \.self) { year in
                        Text(String(year))
                            .tag(year)
                            .font(NovaPalette.bodyFont())
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
                .padding(.horizontal, 20)
            }

            Button(action: handleChildAgeConfirmed) {
                Text("Next")
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(NovaPalette.novaOrange)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .accessibilityLabel("Confirm birth year")
        }
    }

    // MARK: - Parent Verification Stage

    private var parentYearRange: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        let maxParentYear = currentYear - 18
        return Array((1950...maxParentYear).reversed())
    }

    private func parentVerification() -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Now, we need to verify you're a parent!")
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)

                Text("What year were YOU born?")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)

                Picker("Birth Year", selection: $parentBirthYear) {
                    ForEach(parentYearRange, id: \.self) { year in
                        Text(String(year))
                            .tag(year)
                            .font(NovaPalette.bodyFont())
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
                .padding(.horizontal, 20)
            }

            HStack(spacing: 12) {
                Button(action: {
                    errorMessage = nil
                    stage = .childAge
                }) {
                    Text("Back")
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(NovaPalette.novaCardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(NovaPalette.novaBlue, lineWidth: 2)
                        )
                }

                Button(action: handleParentVerification) {
                    Text("Verify")
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(NovaPalette.novaOrange)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .accessibilityLabel("Verify parent age")
        }
    }

    // MARK: - Actions

    private func handleChildAgeConfirmed() {
        errorMessage = nil
        stage = .parentVerification
    }

    private func handleParentVerification() {
        let currentYear = Calendar.current.component(.year, from: Date())
        let parentAge = currentYear - parentBirthYear

        if parentAge >= 18 {
            // Success
            hasPassedAgeGate = true
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
        } else {
            // Fail
            errorMessage = "Please ask a parent or guardian (18+) to help set up Nova"
            let impact = UIImpactFeedbackGenerator(style: .rigid)
            impact.impactOccurred()
        }
    }
}

// MARK: - Supporting Types

enum AgeGateStage {
    case childAge
    case parentVerification
}

#Preview {
    AgeGateView()
}
