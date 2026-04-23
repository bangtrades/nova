import UIKit

/// Canonical haptic ladder for Nova Kids (S11-06 → swept in S11-15).
///
/// Every Tier 1 surface that fires haptic feedback goes through this namespace
/// so the feel stays consistent as the app grows. The three call sites map to
/// the three beats in any interactive moment:
///
/// - `tap()` — an acknowledgement. Something was received. Light impact.
/// - `success()` — a celebration. The user accomplished the thing. Heavy impact
///   plus the system success notification so VoiceOver users also get the
///   "you did it" signal.
/// - `wrong()` — a gentle correction. Not the same as an error alert; it's a
///   "try again" beat. Rigid impact feels like a soft bump, which is kinder
///   than the system `.error` notification that reads as "you broke something"
///   to kids.
///
/// ## Why a namespace, not inline `UIImpactFeedbackGenerator(...)`
///
/// The palette is already consolidated (S11-02), buttons already have a shared
/// style (S11-03). Haptics are the last place where every view used to
/// hand-roll its own feel. This file makes the three beats nameable so future
/// reviews can grep for `NovaHaptics.` and see the whole sensory vocabulary at
/// once. It also gives us a single place to mute haptics if we ever want a
/// per-profile toggle (e.g. "library mode" for noise-sensitive environments).
///
/// ## Usage
///
/// ```swift
/// Button("Select") { NovaHaptics.tap() }
/// // later, on answer eval:
/// isCorrect ? NovaHaptics.success() : NovaHaptics.wrong()
/// ```
///
/// Call sites are synchronous and safe from any thread UIKit permits
/// `UIFeedbackGenerator` use from — in practice, the main thread. All Nova
/// view models publish state on `@MainActor`, so the common call pattern
/// (`NovaHaptics.success()` fired from an `@MainActor`-isolated view) is fine.
public enum NovaHaptics {
    /// Light impact — the "acknowledge" beat. Fire on secondary-button taps,
    /// option selections before commitment, minor UI acknowledgements.
    ///
    /// Matches the inline `UIImpactFeedbackGenerator(style: .light)` used by
    /// `NovaSecondaryButtonStyle` (S11-03). S11-15 will sweep those call sites
    /// to use this helper.
    public static func tap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Medium impact — the "commit" beat. Fire on primary-button taps, quiz
    /// option confirmation, form submission. Sits between `tap()` and
    /// `success()`: more decisive than an acknowledgement, less emphatic than
    /// a celebration.
    ///
    /// Matches the inline `UIImpactFeedbackGenerator(style: .medium)` used by
    /// `NovaPrimaryButtonStyle` (S11-03).
    public static func commit() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Heavy impact + success notification — the "celebrate" beat. Fire on
    /// quiz-correct, badge unlock, level-up. The pairing is deliberate: heavy
    /// impact gives the physical "thunk of success", and the notification
    /// feedback is what VoiceOver hooks into so blind users receive the same
    /// celebration cue as sighted users.
    ///
    /// UINotificationFeedbackGenerator requires a separate instance from the
    /// impact generator — both fire here so callers don't have to remember
    /// the pairing.
    public static func success() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
    }

    /// Rigid impact — the "try again" beat. Fire on wrong-answer feedback,
    /// invalid-input gentle rejection, parental-gate fail. Rigid is crisper
    /// than light but softer than heavy; it reads as "that didn't land" without
    /// sounding alarming.
    ///
    /// Deliberately **not** `UINotificationFeedbackGenerator(.error)` or
    /// `(.warning)`: those are for "something went wrong" moments, not for
    /// "let's try that again" moments. For kids, the distinction matters —
    /// the wrong-answer beat should invite retry, not signal failure.
    public static func wrong() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred()
    }
}
