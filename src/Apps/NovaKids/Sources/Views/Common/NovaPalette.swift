import SwiftUI

/// Nova Kids design system — color palette, typography, and helpers.
///
/// All colors are adaptive (Light + Dark Mode). Typography uses Dynamic Type
/// semantic fonts with the .rounded design for a kid-friendly feel.
public struct NovaPalette {
    // MARK: - Adaptive Colors (Light / Dark)

    /// Primary brand blue — vibrant in both modes
    public static let novaBlue = Color(light: .init(red: 0.29, green: 0.56, blue: 0.85),
                                        dark: .init(red: 0.40, green: 0.65, blue: 0.95))

    /// Accent orange for CTAs
    public static let novaOrange = Color(light: .init(red: 1.0, green: 0.55, blue: 0.26),
                                          dark: .init(red: 1.0, green: 0.62, blue: 0.35))

    /// Success green
    public static let novaGreen = Color(light: .init(red: 0.36, green: 0.72, blue: 0.36),
                                         dark: .init(red: 0.42, green: 0.78, blue: 0.42))

    /// Sparky's purple
    public static let novaPurple = Color(light: .init(red: 0.61, green: 0.35, blue: 0.71),
                                          dark: .init(red: 0.72, green: 0.48, blue: 0.82))

    /// Stars and badges yellow
    public static let novaYellow = Color(light: .init(red: 1.0, green: 0.85, blue: 0.24),
                                          dark: .init(red: 1.0, green: 0.88, blue: 0.35))

    /// Hearts and favorites pink
    public static let novaPink = Color(light: .init(red: 1.0, green: 0.42, blue: 0.42),
                                        dark: .init(red: 1.0, green: 0.52, blue: 0.52))

    /// App background — near-white in light, true dark in dark
    public static let novaBackground = Color(light: .init(red: 0.97, green: 0.98, blue: 0.99),
                                              dark: .init(red: 0.11, green: 0.11, blue: 0.13))

    /// Card/surface background — white in light, elevated surface in dark
    public static let novaCardBackground = Color(light: .white,
                                                  dark: .init(red: 0.17, green: 0.17, blue: 0.19))

    // MARK: - Typography (Dynamic Type + Rounded Design)
    //
    // All fonts scale with system Dynamic Type settings.
    // Apply .fontDesign(.rounded) on the containing view for the kid-friendly feel,
    // OR use these helpers which return appropriately-weighted semantic fonts.

    /// Title — .title weight bold (≈28pt default, scales with Dynamic Type)
    public static func titleFont() -> Font {
        .title.weight(.bold)
    }

    /// Heading — .title2 weight semibold (≈22pt default, scales)
    public static func headingFont() -> Font {
        .title2.weight(.semibold)
    }

    /// Body — .body (≈17pt default, scales)
    public static func bodyFont() -> Font {
        .body
    }

    /// Caption — .caption (≈12pt default, scales)
    public static func captionFont() -> Font {
        .caption
    }

    /// Large body — .title3 (≈20pt default, scales)
    public static func largeBodyFont() -> Font {
        .title3
    }

    /// Small heading — .headline (≈17pt semibold default, scales)
    public static func smallHeadingFont() -> Font {
        .headline
    }

    // MARK: - View Modifier for Rounded Design

    /// Apply this to root views to get the rounded font design throughout.
    /// Usage: `.fontDesign(.rounded)` on the outermost container.
    public static let fontDesign: Font.Design = .rounded

    // MARK: - Helper

    /// Returns a color for a learning path based on a string identifier.
    public static func pathColor(for pathId: String) -> Color {
        let colors: [Color] = [novaBlue, novaOrange, novaPurple, novaGreen, novaPink, novaYellow]
        let hash = pathId.hashValue
        let index = abs(hash) % colors.count
        return colors[index]
    }
}

// MARK: - Color+Adaptive Extension

extension Color {
    /// Creates an adaptive color with separate light/dark mode values.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}
