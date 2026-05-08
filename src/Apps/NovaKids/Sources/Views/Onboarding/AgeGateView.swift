import SwiftUI

/// Age verification screen shown on initial launch (before onboarding).
///
/// Kid must confirm their birth year, then parent must enter their
/// birth year to verify they're 18+. Once passed, stored via
/// `@AppStorage("hasPassedAgeGate")` with no way to bypass.
/// COPPA-compliant design.
///
/// Visual contract: classroom paper note pinned to a soft chalkboard
/// veil so the gate reads as the same workbook chrome as the rest of
/// NovaKids — not a generic system form. The lock icon, action
/// buttons, and the inline error card all pull from
/// `NovaPalette.classroom*` tokens.
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
            chalkboardBackdrop
                .ignoresSafeArea()

            VStack(spacing: 32) {
                header

                Spacer()

                if stage == .childAge {
                    childAgePicker()
                } else {
                    parentVerification()
                }

                Spacer()

                if let error = errorMessage {
                    errorCard(message: error)
                        .padding(.horizontal, 20)
                }

                Spacer()
            }
            .padding(.vertical, 32)
        }
    }

    // MARK: - Backdrop & header

    private var chalkboardBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    NovaPalette.classroomChalkboard.opacity(0.92),
                    NovaPalette.classroomChalkboard,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [
                    NovaPalette.classroomChalkDust.opacity(0.18),
                    Color.clear,
                ],
                center: .center,
                startRadius: 60,
                endRadius: 360
            )
            .accessibilityHidden(true)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            // Lock-shaped sticker — school-red lock on a sun disc with an
            // ink stroke. Reads as "a teacher needs to unlock this" rather
            // than the previous purple bubble.
            ZStack {
                Circle()
                    .fill(NovaPalette.classroomSun)
                    .frame(width: 76, height: 76)
                    .overlay {
                        Circle()
                            .stroke(NovaPalette.classroomInk, lineWidth: 2)
                    }
                    .shadow(color: NovaPalette.classroomInk.opacity(0.20), radius: 4, x: 0, y: 2)

                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(NovaPalette.classroomSchoolRed)
                    .accessibilityHidden(true)
            }

            Text("Getting Started")
                .font(NovaPalette.headingFont())
                .foregroundStyle(NovaPalette.classroomChalkDust)

            Text("A grown-up needs to help you get started!")
                .font(NovaPalette.bodyFont())
                .foregroundStyle(NovaPalette.classroomChalkDust.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
    }

    // MARK: - Child Age Stage

    private func childAgePicker() -> some View {
        paperPanel {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("What year were you born?")
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(NovaPalette.classroomInk)

                    Picker("Birth Year", selection: $childBirthYear) {
                        ForEach(minChildYear...maxChildYear, id: \.self) { year in
                            Text(String(year))
                                .tag(year)
                                .font(NovaPalette.bodyFont())
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }

                Button(action: handleChildAgeConfirmed) {
                    Text("Next")
                }
                .novaPrimary()
                .accessibilityLabel("Confirm birth year")
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Parent Verification Stage

    private var parentYearRange: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        let maxParentYear = currentYear - 18
        return Array((1950...maxParentYear).reversed())
    }

    private func parentVerification() -> some View {
        paperPanel {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Now, we need to verify you're a parent!")
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(NovaPalette.classroomInk)
                        .multilineTextAlignment(.center)

                    Text("What year were YOU born?")
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(NovaPalette.classroomInk.opacity(0.78))
                        .multilineTextAlignment(.center)

                    Picker("Birth Year", selection: $parentBirthYear) {
                        ForEach(parentYearRange, id: \.self) { year in
                            Text(String(year))
                                .tag(year)
                                .font(NovaPalette.bodyFont())
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 150)
                }

                HStack(spacing: 12) {
                    Button {
                        errorMessage = nil
                        stage = .childAge
                    } label: {
                        Text("Back")
                    }
                    .novaSecondary()

                    Button(action: handleParentVerification) {
                        Text("Verify")
                    }
                    .novaPrimary()
                }
                .accessibilityLabel("Verify parent age")
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Shared paper panel

    /// Wraps stage content in a classroom paper card so the gate reads
    /// as a paper note pinned over the chalkboard veil.
    @ViewBuilder
    private func paperPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(Spacing.lg)
            .frame(maxWidth: 520)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(NovaPalette.classroomPaper)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.45), lineWidth: 2)
            }
            .shadow(color: NovaPalette.classroomInk.opacity(0.20), radius: 10, x: 0, y: 4)
    }

    // MARK: - Error card

    private func errorCard(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(NovaPalette.classroomSchoolRed)
                .accessibilityHidden(true)

            Text(message)
                .font(NovaPalette.bodyFont())
                .foregroundStyle(NovaPalette.classroomInk)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NovaPalette.classroomPaper)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NovaPalette.classroomSchoolRed.opacity(0.65), lineWidth: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Verification failed: \(message)")
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
            // Success — parent verified. Celebrate beat; the system success
            // notification also gives VoiceOver users the "you're through" cue.
            hasPassedAgeGate = true
            NovaHaptics.success()
        } else {
            // Fail — try-again beat (NOT an error alert; we invite retry rather
            // than signal "you broke something"). See NovaHaptics.wrong docs.
            errorMessage = "Please ask a parent or guardian (18+) to help set up Nova"
            NovaHaptics.wrong()
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
