import SwiftUI

/// Unified navigation chrome for every Nova Kids surface (S11-08).
///
/// Before this modifier, each top-level screen spelled out its own
/// `.navigationTitle(...)` + `.navigationBarTitleDisplayMode(.inline)` pair.
/// Some used the system title font, some left the title empty to hand the
/// chrome back to a custom in-content greeting. None explicitly set a
/// toolbar background, which meant the nav bar's color was whatever UIKit's
/// material stack picked for a given build — often a subtle white strip that
/// broke the flat comic-book page the rest of the screen works hard to
/// establish.
///
/// `novaNavigationStyle(title:)` consolidates three decisions into one call:
///
/// 1. **Inline title display mode.** Nova Kids is a tab-bar app; large
///    pull-down titles collide with an already-tall bottom tab strip. Inline
///    keeps the header compact and the usable screen area tall.
/// 2. **Seamless toolbar background.** The bar is painted with
///    `NovaPalette.novaBackground` — the same cream the content ZStack sits
///    on — and forced `.visible`. We picked `novaBackground` over `.page`
///    (the planning-time candidate) intentionally: `page` is the card-paper
///    off-white that surfaces like `NovaCard` use, and painting the bar
///    that color would leave a subtle horizontal seam where the nav bar
///    meets the content background. `novaBackground` makes the seam
///    disappear, which reads as one unified comic-book page. The `.visible`
///    hint is mandatory on iOS 17+ — without it the toolbarBackground call
///    is only honored under scroll-edge materials and the default white
///    strip wins.
/// 3. **Bangers principal title.** A non-empty `title` renders as a
///    `ToolbarItem(placement: .principal)` carrying `Text(title)` in
///    `NovaPalette.displayFont(size: 20)` on `NovaPalette.ink`. Empty
///    titles render no principal view at all — the intentional escape
///    hatch for screens like `EnhancedHomeView` and `DashyView` that own
///    their top chrome with an in-content greeting and want the nav bar
///    title-less.
///
/// ## Composition with per-screen toolbar items
///
/// The modifier only claims the `.principal` placement. Screens can still
/// add trailing or leading `ToolbarItem`s (e.g. a settings gear, a close
/// button) on top of this modifier — SwiftUI composes multiple `.toolbar`
/// modifiers by union, so per-screen items stack on the shared principal
/// title without collision.
///
/// ## Usage
///
/// Attach to the `NavigationStack`'s content side, in the same slot the
/// legacy `.navigationTitle` + `.navigationBarTitleDisplayMode` pair used
/// to occupy:
///
/// ```swift
/// NavigationStack {
///     ZStack { ... }
///         .novaNavigationStyle(title: "Trophies")
/// }
/// ```
///
/// Inline-title APIs are only valid inside a navigation container, which
/// is why the body lives on `View` rather than on `NavigationStack` itself.
public struct NovaNavigationStyleModifier: ViewModifier {
    /// Inline title text. Pass `""` for screens that render their own
    /// in-content greeting and want the nav bar title-less.
    let title: String

    public func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(NovaPalette.novaBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { titleToolbar }
    }

    /// Principal-placement Bangers title. Built via `@ToolbarContentBuilder`
    /// so an empty title produces zero toolbar items (rather than an empty
    /// frame that could still claim horizontal space in the bar). This is
    /// the clean escape hatch for screens with in-content greetings.
    @ToolbarContentBuilder
    private var titleToolbar: some ToolbarContent {
        if !title.isEmpty {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(NovaPalette.displayFont(size: 20))
                    .foregroundStyle(NovaPalette.ink)
                    // Bangers is wider than the system font. A long title
                    // (e.g. "Badge Details" at accessibility type size) can
                    // overflow the principal slot before UIKit truncates.
                    // Shrink to 75 % before clipping so the title always
                    // renders as one line — comic-book energy requires the
                    // whole word to be visible.
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }
}

public extension View {
    /// Apply the Nova Kids unified navigation chrome.
    ///
    /// Consolidates inline display mode, a seamless `novaBackground` toolbar
    /// fill, and an optional Bangers principal title into a single call.
    /// See `NovaNavigationStyleModifier` for the design rationale.
    ///
    /// - Parameter title: The inline title rendered in Bangers on
    ///   `NovaPalette.ink`. Pass `""` when the screen owns its chrome with
    ///   an in-content greeting (EnhancedHomeView, DashyView) and should
    ///   leave the nav bar title-less.
    func novaNavigationStyle(title: String = "") -> some View {
        modifier(NovaNavigationStyleModifier(title: title))
    }
}
