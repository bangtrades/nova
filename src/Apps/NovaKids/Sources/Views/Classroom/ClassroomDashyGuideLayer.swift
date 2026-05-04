import SwiftUI

public struct ClassroomDashyGuideLayer: View {
    let prompt: String

    @EnvironmentObject private var narrator: NavigationNarrator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dashyState: DashyAnimationState = .idle
    @State private var isVisible = false
    @State private var resetTask: Task<Void, Never>?

    public init(prompt: String) {
        self.prompt = prompt
    }

    public var body: some View {
        Button {
            repeatPrompt()
        } label: {
            HStack(alignment: .center, spacing: Spacing.sm) {
                DashyCharacterView(state: $dashyState)
                    .frame(width: 112, height: 112)
                    .accessibilityHidden(true)

                DashySpeechBubble(tailSide: .leading, horizontalPadding: Spacing.md, verticalPadding: Spacing.sm + Spacing.xs) {
                    Text(prompt)
                        .font(NovaPalette.bodyFont().weight(.semibold))
                        .foregroundStyle(NovaPalette.ink)
                        .lineLimit(3)
                        .minimumScaleFactor(0.78)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible || reduceMotion ? 0 : -8)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: isVisible)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dashy says, \(prompt)")
        .accessibilityHint("Double tap to hear Dashy repeat this classroom hint.")
        .accessibilityAddTraits(.isButton)
        .onAppear {
            isVisible = true
            // The active HomeView classroom route does not attach `.narrate("home")`;
            // `classroomHome` is the stable narration key for this surface.
            narrator.narrate("classroomHome", script: prompt)
        }
        .onDisappear {
            resetTask?.cancel()
        }
    }

    private func repeatPrompt() {
        resetTask?.cancel()
        dashyState = .talking
        narrator.narrate("classroomHome", script: prompt, force: true)

        resetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            dashyState = .idle
        }
    }
}

#Preview {
    ClassroomDashyGuideLayer(prompt: "Tap the chalkboard to keep learning.")
        .environmentObject(NavigationNarrator(voiceManager: nil))
        .padding()
        .background(NovaPalette.novaBackground)
}
