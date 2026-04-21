import SwiftUI
import UIKit

// MARK: - Spacing (S11-01)
//
// 8-point grid with a 4-point half-step. Every new padding / HStack spacing /
// VStack spacing site in Tier 1 screens should use these tokens, so the
// vertical rhythm holds across screens without every view inventing its own
// numbers. Values are CGFloat to slot directly into SwiftUI `.padding(…)` /
// `HStack(spacing:)` / `VStack(spacing:)` without conversion.
//
// Naming follows the t-shirt convention so future work can insert sizes
// (e.g., `md2` between `md` and `lg`) without renumbering everything.
public enum Spacing {
    /// 4pt — tight gaps (inline icons, chip padding)
    public static let xs: CGFloat = 4
    /// 8pt — default inter-element gap
    public static let sm: CGFloat = 8
    /// 16pt — default padding / section interior
    public static let md: CGFloat = 16
    /// 24pt — section separation
    public static let lg: CGFloat = 24
    /// 32pt — screen-level padding
    public static let xl: CGFloat = 32
    /// 48pt — hero / splash spacing
    public static let xxl: CGFloat = 48
}

/// Nova Kids design system — color palette, typography, and helpers.
///
/// All colors are adaptive (Light + Dark Mode). Typography uses Dynamic Type
/// semantic fonts with the .rounded design for a kid-friendly feel.
///
/// ## S11 Palette Structure
///
/// Sprint 11 consolidated the palette from a flat 6-rainbow to **3 primaries +
/// 1 surface**, with the rainbow demoted to `NovaPalette.Category.*` for
/// lesson-category tags only. New screens default to the 3+1; rainbow is still
/// available but is NOT the first choice for new surfaces.
///
/// - `ink` / `page` are an **inverse adaptive pair** — `ink` is dark navy in
///   light mode and warm off-white in dark mode; `page` is the opposite. This
///   gives the "comic-book ink on paper" metaphor a clean dark-mode flip:
///   `ink.opacity(0.05)` reads as subtle dark tint in light mode and subtle
///   light tint in dark mode without any branching.
/// - `coral` / `sun` are brightened slightly in dark mode for legibility but
///   stay recognizable as the same hue.
/// - `Category.*` holds the legacy 6-rainbow; back-compat aliases like
///   `novaBlue` still resolve to `Category.blue` so the 280+ existing call
///   sites keep working without churn.
public struct NovaPalette {

    // MARK: - 3+1 Primary Palette (S11-02)

    /// Primary display / text / outline. Dark navy on light surface; warm
    /// off-white on dark surface. Use for titles, body copy, strokes, and
    /// subtle tints via `.ink.opacity(0.05)`.
    public static let ink = Color(
        light: .init(red: 0.102, green: 0.129, blue: 0.220), // #1A2138
        dark:  .init(red: 0.980, green: 0.965, blue: 0.929)  // #FAF6ED (paper in dark)
    )

    /// Primary action / highlight / energy. Coral-red.
    public static let coral = Color(
        light: .init(red: 1.000, green: 0.357, blue: 0.298), // #FF5B4C
        dark:  .init(red: 1.000, green: 0.478, blue: 0.431)  // #FF7A6E (brightened for dark)
    )

    /// Celebration / secondary accent / Dashy body. Sunlit yellow.
    public static let sun = Color(
        light: .init(red: 1.000, green: 0.808, blue: 0.278), // #FFCE47
        dark:  .init(red: 1.000, green: 0.843, blue: 0.396)  // #FFD765
    )

    /// Default surface. Warm off-white (paper-like) in light mode; dark navy
    /// (inverse of `ink`) in dark mode. Use instead of `Color.white` /
    /// `Color.black` for surfaces so the full app flips cleanly.
    public static let page = Color(
        light: .init(red: 0.980, green: 0.965, blue: 0.929), // #FAF6ED
        dark:  .init(red: 0.102, green: 0.129, blue: 0.220)  // #1A2138
    )

    // MARK: - Category Palette (rainbow — demoted to lesson-category tags)
    //
    // These are the original S0-S10 colors, unchanged. Use ONLY for lesson-
    // category theming (science / math / story / etc.) — not for primary
    // surfaces or actions. For those, use the 3+1 above.

    public enum Category {
        /// Primary brand blue — vibrant in both modes
        public static let blue = Color(
            light: .init(red: 0.29, green: 0.56, blue: 0.85),
            dark:  .init(red: 0.40, green: 0.65, blue: 0.95)
        )

        /// Accent orange for CTAs
        public static let orange = Color(
            light: .init(red: 1.0, green: 0.55, blue: 0.26),
            dark:  .init(red: 1.0, green: 0.62, blue: 0.35)
        )

        /// Success green
        public static let green = Color(
            light: .init(red: 0.36, green: 0.72, blue: 0.36),
            dark:  .init(red: 0.42, green: 0.78, blue: 0.42)
        )

        /// Dashy (née Sparky) purple
        public static let purple = Color(
            light: .init(red: 0.61, green: 0.35, blue: 0.71),
            dark:  .init(red: 0.72, green: 0.48, blue: 0.82)
        )

        /// Stars and badges yellow
        public static let yellow = Color(
            light: .init(red: 1.0, green: 0.85, blue: 0.24),
            dark:  .init(red: 1.0, green: 0.88, blue: 0.35)
        )

        /// Hearts and favorites pink
        public static let pink = Color(
            light: .init(red: 1.0, green: 0.42, blue: 0.42),
            dark:  .init(red: 1.0, green: 0.52, blue: 0.52)
        )
    }

    // MARK: - Back-compat aliases (keep 280+ existing call sites working)
    //
    // Flat names like `NovaPalette.novaBlue` remain the public-facing handles
    // for the rainbow colors so S11-02 doesn't cascade into a palette-wide
    // find-and-replace across every screen. New code should prefer
    // `NovaPalette.Category.blue` / `.orange` / `.green` / `.purple` /
    // `.yellow` / `.pink` to make category-intent explicit.

    public static let novaBlue   = Category.blue
    public static let novaOrange = Category.orange
    public static let novaGreen  = Category.green
    public static let novaPurple = Category.purple
    public static let novaYellow = Category.yellow
    public static let novaPink   = Category.pink

    // MARK: - Surfaces (back-compat)

    /// App background — near-white in light, true dark in dark. Prefer `.page`
    /// in new code; this alias is kept for existing call sites.
    public static let novaBackground = Color(
        light: .init(red: 0.97, green: 0.98, blue: 0.99),
        dark:  .init(red: 0.11, green: 0.11, blue: 0.13)
    )

    /// Card/surface background — white in light, elevated surface in dark.
    /// S11-03 will introduce `NovaCard` as the canonical card container;
    /// this remains the fill color used inside it.
    public static let novaCardBackground = Color(
        light: .white,
        dark:  .init(red: 0.17, green: 0.17, blue: 0.19)
    )

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

    // MARK: - Display Font (S11-04)
    //
    // `Bangers` is the comic-book display face used for card titles, action
    // words, and the Dashy speech-bubble header. We keep the runtime lookup
    // defensive: if the .ttf file isn't registered yet (or fails to load for
    // any reason), we fall back to SF Rounded Heavy so the app NEVER crashes
    // or renders as system default. That fallback also gives designers a
    // reasonable default even before the custom font is dropped in.
    //
    // Drop `Bangers-Regular.ttf` into `Resources/Fonts/` and add its filename
    // to the `UIAppFonts` array in Info.plist. See
    // `Resources/Fonts/README.md` for exact instructions.

    /// Exact PostScript name of the Bangers font. Verified via
    /// `UIFont.fontNames(forFamilyName: "Bangers")` once the .ttf is
    /// registered — the PostScript name for Bangers-Regular is "Bangers-Regular".
    private static let bangersPostScriptName = "Bangers-Regular"

    /// Display font for card titles, hero headlines, and action words.
    ///
    /// Returns the Bangers custom font if it's registered, otherwise SF
    /// Rounded Heavy at the same size. The size is relative (points), so for
    /// Dynamic Type-aware call sites pair with `.dynamicTypeSize(...)` on
    /// the containing view or use `.scaledToFit()` in the layout.
    ///
    /// - Parameter size: Point size for the font.
    /// - Returns: A SwiftUI Font — Bangers if available, SF Rounded Heavy fallback.
    public static func displayFont(size: CGFloat) -> Font {
        if isBangersRegistered {
            return .custom(bangersPostScriptName, size: size)
        }
        return .system(size: size, weight: .heavy, design: .rounded)
    }

    /// Cached check for whether the custom display font is available at
    /// runtime. Looking up every display-font call site via UIFont is cheap
    /// but not free, and a single app launch won't see the font appear
    /// partway through — so we compute this once and reuse.
    private static let isBangersRegistered: Bool = {
        UIFont(name: bangersPostScriptName, size: 12) != nil
    }()

    // MARK: - View Modifier for Rounded Design

    /// Apply this to root views to get the rounded font design throughout.
    /// Usage: `.fontDesign(.rounded)` on the outermost container.
    public static let fontDesign: Font.Design = .rounded

    // MARK: - Helper

    /// Returns a color for a learning path based on a string identifier.
    /// Uses the Category rainbow — this is exactly the kind of per-lesson
    /// theming the rainbow is still good for.
    public static func pathColor(for pathId: String) -> Color {
        let colors: [Color] = [
            Category.blue,
            Category.orange,
            Category.purple,
            Category.green,
            Category.pink,
            Category.yellow,
        ]
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
