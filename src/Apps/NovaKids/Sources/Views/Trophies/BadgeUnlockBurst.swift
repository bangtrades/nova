import SwiftUI

/// Comic-book "UNLOCKED!" burst that fires on first view of an earned badge
/// in the detail sheet (S11-07).
///
/// Cousin of `QuizPowReaction` — same design vocabulary (Bangers display
/// face, sunlit-yellow fill, stacked-ink-shadow stroke, spring scale-in with
/// a small rotation), but the word is "UNLOCKED!" and the burst is paired
/// with `NovaHaptics.success()` instead of riding the parent view's haptic.
///
/// ## Why extract it
///
/// Keeping the reaction as its own view (rather than inlining the animation
/// inside `BadgeDetailSheet`) does two things. First, the burst's animation
/// state — scale, rotation, opacity, task handle — stays encapsulated and
/// doesn't leak into the sheet's other responsibilities. Second, future
/// celebration moments (level-up, streak milestone) can reuse this file's
/// pattern by substituting the word and tuning the timing, without needing
/// to re-derive the comic-book stroke idiom each time.
///
/// ## Relationship to `QuizPowReaction`
///
/// The two views are intentionally almost-identical in visual language:
/// same font, same stroke technique, same spring curve. A child who sees
/// the POW burst on a correct quiz answer and later the UNLOCKED burst on
/// a badge reveal is learning one celebration language, not two. If we ever
/// want to factor out the shared rendering, it'd be a generic
/// `ComicWordBurst(text: String)` — but with two call sites so far the
/// duplication is cheap enough to prefer clarity over DRY.
///
/// ## Accessibility
///
/// Marked `accessibilityHidden(true)` — the burst's meaning is already
/// conveyed by (a) the badge's earned state visible in the hero block, (b)
/// the earned-date string shown beneath, and (c) the `NovaHaptics.success()`
/// beat which VoiceOver picks up via its notification feedback. Adding a
/// third announcement would over-verbose the moment.
///
/// Respects `@Environment(\.accessibilityReduceMotion)`: degrades to a
/// plain fade with no scale or rotation when reduce motion is on.
public struct BadgeUnlockBurst: View {
    /// Whether the reaction is currently visible. Parent flips this to true
    /// when the sheet appears for an earned badge; the view's `.onChange`
    /// runs the animation cycle and flips it back when the hold elapses.
    @Binding var isActive: Bool

    /// Internal scale — animates 0.3 → 1.1 (overshoot) → 1.0 via spring.
    @State private var scale: CGFloat = 0.3

    /// Internal rotation — held between -6 and +4 degrees so the word
    /// reads kinetic without being disorienting on a detail sheet where
    /// the user has specifically opted into looking at the badge.
    @State private var rotation: Double = -6

    /// Internal opacity — 0 → 1 on enter, 1 → 0 on exit.
    @State private var opacity: Double = 0

    /// Task handle so the hold/exit cycle cancels cleanly if the sheet
    /// dismisses mid-burst.
    @State private var cycleTask: Task<Void, Never>?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isActive: Binding<Bool>) {
        self._isActive = isActive
    }

    public var body: some View {
        // "UNLOCKED!" is 9 characters — sized at 48pt it reads large without
        // clipping on the narrowest iPhone sheet. POW! at 72pt is shorter
        // so it can afford to be bigger; the burst language stays consistent.
        Text("UNLOCKED!")
            .font(NovaPalette.displayFont(size: 48))
            .foregroundStyle(NovaPalette.sun)
            // Stacked zero-radius ink shadows are the idiomatic way to fake
            // a text stroke in SwiftUI — four cardinal offsets at 2pt give a
            // crisp 2pt outline without dropping to Core Text.
            .shadow(color: NovaPalette.ink, radius: 0, x:  2, y:  0)
            .shadow(color: NovaPalette.ink, radius: 0, x: -2, y:  0)
            .shadow(color: NovaPalette.ink, radius: 0, x:  0, y:  2)
            .shadow(color: NovaPalette.ink, radius: 0, x:  0, y: -2)
            // Drop shadow for the "lifted off the page" paper feel. Matches
            // `NovaCard`'s shadow recipe so the burst feels native to the
            // same world as the card underneath.
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
    /// 1.0s hold → exit (fade-out) → reset so a re-trigger starts from the
    /// pre-burst pose.
    private func runBurst() {
        cycleTask?.cancel()

        if reduceMotion {
            // Reduce-motion path: plain fade. The moment is still marked by
            // the word appearing and disappearing, but without the
            // transforms that motion-sensitive users opted out of.
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

        // Reset to pre-burst pose so the spring has a starting point.
        scale = 0.3
        rotation = -6
        opacity = 0

        // Spring scale/rotate + fade-in. Overshoot to 1.1 then settle —
        // makes the word feel like it was stamped down, not faded up.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.58)) {
            scale = 1.1
            rotation = 4
            opacity = 1.0
        }

        cycleTask = Task { @MainActor in
            // Hold 1.0s — slightly shorter than POW!'s 1.2s because the
            // trophy sheet gives the user other things to look at
            // (description, criteria, progress) and we don't want to
            // occlude them for too long.
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.easeOut(duration: 0.4)) {
                opacity = 0
                scale = 1.2
                rotation = 6
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
        BadgeUnlockBurst(isActive: $isActive)
            .frame(height: 120)

        Button("Fire UNLOCKED") {
            NovaHaptics.success()
            isActive = true
        }
        .novaPrimary()
    }
    .padding(Spacing.lg)
    .background(NovaPalette.novaBackground)
}
