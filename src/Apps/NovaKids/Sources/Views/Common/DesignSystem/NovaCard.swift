import SwiftUI

/// Canonical comic-book card container for the Nova Kids design system (S11-03).
///
/// `NovaCard` is the single source of truth for card-shaped surfaces: lesson
/// tiles, flipbook pages, dashboard panels, trophy cards. Every card on Tier 1
/// screens should compose through this type so we have one place to tweak the
/// comic-book language (stroke weight, shadow, corner radius) and have it
/// propagate everywhere.
///
/// ## Visual language
///
/// - **20pt corner radius** — rounded enough to read friendly, square enough
///   to feel like a page panel, not a pill.
/// - **2pt ink stroke** — the comic-book outline. Uses `NovaPalette.ink`, so
///   it flips to warm off-white in dark mode and the outline stays legible.
/// - **Paper-texture shadow** — 8pt blur, 4pt y-offset, `ink.opacity(0.08)`.
///   Soft enough to suggest the card is lifted off the page without looking
///   like Material Design elevation.
/// - **Page fill** — the card interior is `NovaPalette.page`, which inverts
///   in dark mode so the card always reads as "lighter than the background"
///   regardless of appearance.
/// - **Accent** — optional side-edge tint (default `coral`) that lets a card
///   carry category identity (e.g. purple for Dashy, orange for practice)
///   without repainting the whole surface.
///
/// ## Usage
///
/// ```swift
/// NovaCard {
///     VStack(alignment: .leading, spacing: Spacing.sm) {
///         Text("What is AI?").font(NovaPalette.headingFont())
///         Text("Let's find out!").font(NovaPalette.bodyFont())
///     }
/// }
///
/// NovaCard(accent: NovaPalette.Category.purple) {
///     DashyGreeting()
/// }
/// ```
///
/// The card expands to whatever its content requires — do not wrap in a
/// `.frame(...)` unless you need a fixed footprint (e.g. horizontal scroll).
public struct NovaCard<Content: View>: View {
    /// Side-accent stripe color. Defaults to coral so cards without a category
    /// still pick up brand energy.
    private let accent: Color

    /// Content to display inside the card.
    private let content: Content

    /// Corner radius for the card. Kept private so every card shares the
    /// same rounding unless we explicitly decide to vary it.
    private let cornerRadius: CGFloat = 20

    /// Stroke width for the ink outline. 2pt reads as a pen line without
    /// feeling crayon-thick.
    private let strokeWidth: CGFloat = 2

    /// Width of the accent stripe on the leading edge.
    private let accentStripeWidth: CGFloat = 6

    public init(
        accent: Color = NovaPalette.coral,
        @ViewBuilder content: () -> Content
    ) {
        self.accent = accent
        self.content = content()
    }

    public var body: some View {
        content
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                NovaPalette.page,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(alignment: .leading) {
                // Accent stripe sits behind the stroke so the ink outline wraps it.
                accent
                    .frame(width: accentStripeWidth)
                    .clipShape(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(NovaPalette.ink, lineWidth: strokeWidth)
            }
            .shadow(
                color: NovaPalette.ink.opacity(0.08),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}

#Preview("NovaCard — default accent") {
    VStack(spacing: Spacing.lg) {
        NovaCard {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("What is AI?")
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(NovaPalette.ink)
                Text("Let's learn what makes a computer smart.")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(NovaPalette.ink.opacity(0.8))
            }
        }

        NovaCard(accent: NovaPalette.Category.purple) {
            HStack(spacing: Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundStyle(NovaPalette.Category.purple)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Meet Dashy")
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(NovaPalette.ink)
                    Text("Your AI learning buddy.")
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(NovaPalette.ink.opacity(0.8))
                }
            }
        }
    }
    .padding(Spacing.lg)
    .background(NovaPalette.novaBackground)
}
