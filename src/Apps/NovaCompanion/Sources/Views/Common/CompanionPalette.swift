import SwiftUI
import NovaCore

/// Nova Companion design system color palette and typography.
///
/// Professional, parent-focused colors and typography. Uses system
/// fonts (not rounded) for a mature, dashboard-like appearance.
///
/// Build fix (Jun 11): the brand colors below were aliases into
/// `NovaPalette` — but that type is compiled only into the NovaKids
/// target, so this file never compiled in the Companion target (broken
/// since the initial commit, masked because nobody built the scheme).
/// The values are inlined verbatim from `NovaPalette.Category`; if the
/// brand palette ever moves into a shared package, re-alias these.
public struct CompanionPalette {
    // MARK: - Brand colors (inlined from NovaPalette.Category)

    public static let novaBlue = dynamicColor(
        light: (0.29, 0.56, 0.85), dark: (0.40, 0.65, 0.95)
    )
    public static let novaOrange = dynamicColor(
        light: (1.0, 0.55, 0.26), dark: (1.0, 0.62, 0.35)
    )
    public static let novaGreen = dynamicColor(
        light: (0.36, 0.72, 0.36), dark: (0.42, 0.78, 0.42)
    )
    public static let novaPurple = dynamicColor(
        light: (0.61, 0.35, 0.71), dark: (0.72, 0.48, 0.82)
    )
    public static let novaYellow = dynamicColor(
        light: (1.0, 0.85, 0.24), dark: (1.0, 0.88, 0.35)
    )
    public static let novaPink = dynamicColor(
        light: (1.0, 0.42, 0.42), dark: (1.0, 0.52, 0.52)
    )

    /// Light/dark adaptive color from RGB triples — local equivalent of
    /// the `Color(light:dark:)` helper that lives in the NovaKids target.
    private static func dynamicColor(
        light: (Double, Double, Double),
        dark: (Double, Double, Double)
    ) -> Color {
        Color(UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }

    // MARK: - Companion-Specific Colors

    /// Light, professional background — #F5F5F7
    public static let companionBackground = Color(red: 0.96, green: 0.96, blue: 0.97)

    /// Card background with subtle border — pure white
    public static let companionCard = Color.white

    /// Status: Draft lesson — #FFC107
    public static let statusDraft = Color(red: 1.0, green: 0.76, blue: 0.03)

    /// Status: Published lesson — #4CAF50
    public static let statusPublished = Color(red: 0.30, green: 0.84, blue: 0.31)

    /// Status: Archived lesson — #9E9E9E
    public static let statusArchived = Color(red: 0.62, green: 0.62, blue: 0.62)

    /// Border color for cards and dividers
    public static let companionBorder = Color(UIColor.systemGray5)

    // MARK: - Typography

    /// Large title font (28pt, system, bold)
    public static func largeTitleFont() -> Font {
        return .system(size: 28, weight: .bold, design: .default)
    }

    /// Title font (24pt, system, bold)
    public static func titleFont() -> Font {
        return .system(size: 24, weight: .bold, design: .default)
    }

    /// Heading font (18pt, system, semibold)
    public static func headingFont() -> Font {
        return .system(size: 18, weight: .semibold, design: .default)
    }

    /// Body font (16pt, system, regular)
    public static func bodyFont() -> Font {
        return .system(size: 16, weight: .regular, design: .default)
    }

    /// Secondary body font (15pt, system, regular)
    public static func secondaryBodyFont() -> Font {
        return .system(size: 15, weight: .regular, design: .default)
    }

    /// Caption font (13pt, system, regular)
    public static func captionFont() -> Font {
        return .system(size: 13, weight: .regular, design: .default)
    }

    /// Small caption font (12pt, system, regular)
    public static func smallCaptionFont() -> Font {
        return .system(size: 12, weight: .regular, design: .default)
    }

    /// Small heading font (15pt, system, semibold) — used by the lesson
    /// preview surfaces ported from the kid app's type ramp.
    public static func smallHeadingFont() -> Font {
        return .system(size: 15, weight: .semibold, design: .default)
    }

    // MARK: - Helper

    /// Returns a color for a learning path based on a string identifier.
    public static func pathColor(for pathId: String) -> Color {
        let colors: [Color] = [novaBlue, novaOrange, novaPurple, novaGreen, novaPink, novaYellow]
        let hash = pathId.hashValue
        let index = abs(hash) % colors.count
        return colors[index]
    }
}
