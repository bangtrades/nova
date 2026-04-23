import SwiftUI
import UIKit

/// Primary call-to-action button style (S11-03).
///
/// Coral fill, ink text, 16pt rounded corners, 0.96 press scale, medium haptic
/// on tap. Use this for the single most important action on a screen: "Start
/// Lesson", "Next", "Save", "Continue".
///
/// ## Why a custom ButtonStyle vs `.buttonStyle(.borderedProminent)`
///
/// `.borderedProminent` uses system tints that don't match Nova's comic-book
/// language and can't carry the ink-outline / press-scale affordance we want.
/// A dedicated style lets every primary CTA in the app share exactly the same
/// shape, animation curve, and haptic so muscle memory builds up.
///
/// ## Usage
///
/// ```swift
/// Button("Start Lesson") { viewModel.start() }
///     .buttonStyle(NovaPrimaryButtonStyle())
///
/// // or via the convenience modifier
/// Button("Start Lesson") { viewModel.start() }
///     .novaPrimary()
/// ```
public struct NovaPrimaryButtonStyle: ButtonStyle {
    /// Corner radius — slightly smaller than `NovaCard` (20pt) so a button
    /// sitting inside a card reads as a distinct element, not a mini-card.
    private let cornerRadius: CGFloat = 16

    /// Scale factor on press. 0.96 feels tactile without being bouncy.
    private let pressedScale: CGFloat = 0.96

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NovaPalette.bodyFont().weight(.semibold))
            .foregroundStyle(NovaPalette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md - 2)  // 14pt — comfy tap target w/o oversizing
            .padding(.horizontal, Spacing.lg)
            .background(
                NovaPalette.coral,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(NovaPalette.ink, lineWidth: 2)
            }
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                // Trigger haptic on press-down only (false → true), not on release.
                // Routed through NovaHaptics.commit() (S11-15) so the whole app
                // shares one sensory ladder — grep `NovaHaptics.` to audit.
                if !oldValue && newValue {
                    NovaHaptics.commit()
                }
            }
    }
}

/// Secondary button style for non-primary actions (S11-03).
///
/// Page fill, ink outline, coral text. Use for "Cancel", "Back", "Learn more",
/// or the non-primary option in a two-button row. A screen should never show
/// two primary buttons at once — if you're tempted, promote one to primary
/// and make the other secondary so the user's eye has a clear first target.
///
/// ## Usage
///
/// ```swift
/// Button("Not now") { dismiss() }
///     .buttonStyle(NovaSecondaryButtonStyle())
///
/// // or via the convenience modifier
/// Button("Not now") { dismiss() }
///     .novaSecondary()
/// ```
public struct NovaSecondaryButtonStyle: ButtonStyle {
    private let cornerRadius: CGFloat = 16
    private let pressedScale: CGFloat = 0.96

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NovaPalette.bodyFont().weight(.semibold))
            .foregroundStyle(NovaPalette.coral)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md - 2)
            .padding(.horizontal, Spacing.lg)
            .background(
                NovaPalette.page,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(NovaPalette.ink, lineWidth: 2)
            }
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { oldValue, newValue in
                // Light haptic for secondary — softer feedback than primary so
                // the user can feel which tier of action they triggered without
                // looking. Routed through NovaHaptics.tap() (S11-15) for ladder
                // consistency.
                if !oldValue && newValue {
                    NovaHaptics.tap()
                }
            }
    }
}

// MARK: - Convenience modifiers
//
// `.novaPrimary()` reads more fluently than `.buttonStyle(NovaPrimaryButtonStyle())`
// at call sites and makes it obvious which buttons opt into the design system.

public extension View {
    /// Apply the Nova primary CTA style (coral fill, ink outline, press scale + haptic).
    func novaPrimary() -> some View {
        buttonStyle(NovaPrimaryButtonStyle())
    }

    /// Apply the Nova secondary CTA style (page fill, ink outline, coral text).
    func novaSecondary() -> some View {
        buttonStyle(NovaSecondaryButtonStyle())
    }
}

#Preview("Button styles") {
    VStack(spacing: Spacing.md) {
        Button("Start Lesson") { }
            .novaPrimary()

        Button("Not now") { }
            .novaSecondary()

        HStack(spacing: Spacing.md) {
            Button("Back") { }
                .novaSecondary()
            Button("Continue") { }
                .novaPrimary()
        }
    }
    .padding(Spacing.lg)
    .background(NovaPalette.novaBackground)
}
