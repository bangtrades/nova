import SwiftUI

/// Welcome header displayed at the top of the Home screen.
///
/// Shows a greeting with the child's name and a waving emoji animation. As of
/// S11-05 the greeting uses the Bangers display font (with SF Rounded Heavy
/// fallback) and the whole block sits in a `NovaCard` with a purple accent so
/// it reads as the first comic-panel on the page.
public struct WelcomeHeader: View {
    /// Child's name to display in greeting.
    let childName: String

    /// Current wave rotation in degrees. `@State` so SwiftUI re-renders when
    /// the animation task flips it between 0° and 15°.
    @State private var waveRotation: Double = 0

    /// Respect the user's reduce-motion preference — skip the wave animation
    /// entirely when the system has motion reduced.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(childName: String) {
        self.childName = childName
    }

    public var body: some View {
        NovaCard(accent: NovaPalette.Category.purple) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Hey \(childName)!")
                        .font(NovaPalette.displayFont(size: 36))
                        .foregroundStyle(NovaPalette.ink)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text("Ready to explore?")
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(NovaPalette.ink.opacity(0.75))
                }

                Spacer()

                // Waving emoji — kept as emoji (not SF Symbol) so it carries
                // the cartoon warmth we want from the hero row.
                Text("👋")
                    .font(.largeTitle)
                    .rotationEffect(.degrees(waveRotation), anchor: .topTrailing)
                    .accessibilityHidden(true)
            }
        }
        .task {
            await animateWaveIfAllowed()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome, \(childName)")
        .accessibilityValue("Ready to explore?")
    }

    /// Swings the wave emoji between 0° and 15° on a 600ms interval. Uses a
    /// structured `Task` (scoped to the view's lifetime via `.task`) instead
    /// of `Timer.scheduledTimer` because Timer callbacks run in a nonisolated
    /// context and can't mutate `@MainActor` `@State` under Swift 6 strict
    /// concurrency without a manual actor hop.
    ///
    /// When ReduceMotion is on, we return immediately — the greeting still
    /// reads fine as a static 👋.
    @MainActor
    private func animateWaveIfAllowed() async {
        guard !reduceMotion else { return }

        // Loop forever; `.task` cancels the task when the view disappears.
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: 0.3)) {
                waveRotation = 15
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                waveRotation = 0
            }
            try? await Task.sleep(nanoseconds: 700_000_000)
        }
    }
}

#Preview {
    WelcomeHeader(childName: "Explorer")
        .padding(Spacing.lg)
        .background(NovaPalette.novaBackground)
}
