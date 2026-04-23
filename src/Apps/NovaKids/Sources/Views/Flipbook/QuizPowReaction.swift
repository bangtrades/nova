import SwiftUI

/// Comic-book "POW!" burst that fires on a correct quiz answer (S11-06).
///
/// The goal is the specific sensory beat kids pattern-match to "I got it
/// right!" — the same beat you'd see in a comic panel when the hero lands
/// their punch. Bangers display type, sunlit-yellow fill, ink outline, and a
/// spring scale-in with a small rotation that makes the word feel like it was
/// slammed onto the page rather than faded in.
///
/// ## Why extract it
///
/// Keeping the reaction as a dedicated view has two benefits. First, its
/// animation vocabulary stays encapsulated — the spring curve, the rotation
/// amount, the hold duration don't leak into the parent view's state. Second,
/// reviewers can see the full celebration in one file instead of chasing
/// animation modifiers through a 400-line quiz view.
///
/// ## Accessibility
///
/// The view is marked `accessibilityHidden(true)` — the meaning is already
/// conveyed by the feedback label ("Correct!") and the `NovaHaptics.success()`
/// beat, both of which VoiceOver picks up. Adding a third announcement for
/// the burst would over-verbose the screen.
///
/// Respects `@Environment(\.accessibilityReduceMotion)`: degrades to a plain
/// fade with no scale or rotation when reduce motion is on.
public struct QuizPowReaction: View {
    /// Whether the reaction is currently visible. Parent flips this to true
    /// on correct answer; the view's `.onChange` runs the animation cycle
    /// and flips it back when done.
    @Binding var isActive: Bool

    /// Internal scale — animates from 0.3 (pre-burst) to 1.1 (slight
    /// overshoot) to 1.0 (rest) via the spring curve.
    @State private var scale: CGFloat = 0.3

    /// Internal rotation in degrees — imparts the "slammed onto the page"
    /// feel. Held between -8 and +8 degrees so it reads as kinetic without
    /// being dizzying.
    @State private var rotation: Double = -8

    /// Internal opacity — animates 0 → 1 on enter, 1 → 0 on exit.
    @State private var opacity: Double = 0

    /// Task handle so the auto-dismiss cycle cancels cleanly if the parent
    /// view disappears mid-burst (e.g. user swipes to next card before the
    /// 1.2s hold elapses).
    @State private var cycleTask: Task<Void, Never>?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isActive: Binding<Bool>) {
        self._isActive = isActive
    }

    public var body: some View {
        // The comic-book stroke is four zero-radius ink shadows cardinal-offset
        // around the yellow fill. SwiftUI doesn't have a direct text-stroke
        // modifier, and stacked shadows are the idiomatic way to fake one
        // without dropping to Core Text. The drop-shadow below them adds the
        // "lifted off the page" paper feel that matches `NovaCard`'s shadow.
        Text("POW!")
            .font(NovaPalette.displayFont(size: 72))
            .foregroundStyle(NovaPalette.Category.yellow)
            .shadow(color: NovaPalette.ink, radius: 0, x:  2, y:  0)
            .shadow(color: NovaPalette.ink, radius: 0, x: -2, y:  0)
            .shadow(color: NovaPalette.ink, radius: 0, x:  0, y:  2)
            .shadow(color: NovaPalette.ink, radius: 0, x:  0, y: -2)
            .shadow(color: NovaPalette.ink.opacity(0.25), radius: 6, x: 3, y: 4)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .accessibilityHidden(true)
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    runBurst()
                }
            }
            .onDisappear {
                cycleTask?.cancel()
            }
    }

    /// Plays one burst cycle: enter (spring scale + rotate + fade-in) →
    /// hold → exit (fade-out) → reset state so the next activation starts
    /// from the pre-burst pose.
    private func runBurst() {
        cycleTask?.cancel()

        if reduceMotion {
            // Reduce-motion path: plain fade with no transform. Still a burst
            // in the sense that it appears and disappears, but without the
            // kinetic scale+rotate that could trigger motion-sensitivity.
            scale = 1.0
            rotation = 0
            withAnimation(.easeIn(duration: 0.2)) {
                opacity = 1.0
            }
            cycleTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    opacity = 0
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                isActive = false
            }
            return
        }

        // Reset to pre-burst pose so the spring has somewhere to come from.
        scale = 0.3
        rotation = -8
        opacity = 0

        // Spring scale/rotate + fade-in. The spring's slight overshoot is
        // what makes the word feel "landed" rather than faded in.
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            scale = 1.1
            rotation = 6
            opacity = 1.0
        }

        cycleTask = Task { @MainActor in
            // Hold the burst for 1.2s — long enough to register but short
            // enough not to block the next swipe.
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.4)) {
                opacity = 0
                scale = 1.25
                rotation = 10
            }

            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            isActive = false
        }
    }
}

#Preview {
    @Previewable @State var isActive = false

    return VStack(spacing: Spacing.xl) {
        QuizPowReaction(isActive: $isActive)
            .frame(height: 120)

        Button("Fire POW") {
            isActive = true
        }
        .novaPrimary()
    }
    .padding(Spacing.lg)
    .background(NovaPalette.novaBackground)
}
