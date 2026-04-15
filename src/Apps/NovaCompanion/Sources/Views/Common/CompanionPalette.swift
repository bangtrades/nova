import SwiftUI
import NovaCore

/// Nova Companion design system color palette and typography.
///
/// Extends NovaPalette with professional, parent-focused colors and typography.
/// Uses system fonts (not rounded) for a mature, dashboard-like appearance.
public struct CompanionPalette {
    // MARK: - Color Palette (from NovaPalette)

    public static let novaBlue = NovaPalette.novaBlue
    public static let novaOrange = NovaPalette.novaOrange
    public static let novaGreen = NovaPalette.novaGreen
    public static let novaPurple = NovaPalette.novaPurple
    public static let novaYellow = NovaPalette.novaYellow
    public static let novaPink = NovaPalette.novaPink

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

    // MARK: - Helper

    /// Returns a color for a learning path based on a string identifier.
    public static func pathColor(for pathId: String) -> Color {
        let colors: [Color] = [novaBlue, novaOrange, novaPurple, novaGreen, novaPink, novaYellow]
        let hash = pathId.hashValue
        let index = abs(hash) % colors.count
        return colors[index]
    }
}
