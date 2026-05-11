import Foundation
import SwiftUI

/// Dev-only overlay that visualizes the classroom-home hotspot
/// rectangles **and** the reserved zones from the 2.5D art contract on
/// top of the rendered scene.
///
/// **This is QA tooling, not product UI.** It exists so a designer +
/// SwiftUI engineer can confirm at a glance that:
///
/// - The chalkboard, bookshelf, trophy shelf, mission board, Dashy desk,
///   project table, and backpack/cubby tap zones in `ClassroomSceneModel`
///   line up with the generated 2.5D classroom artwork.
/// - The reserved Dashy speech-bubble zone (center column of the scene)
///   stays visually calm in the artwork — no busy patterns, no posters,
///   no high-saturation detail under where the bubble floats at runtime.
/// - The required clear visual surfaces inside the chalkboard, trophy
///   case, mission board, and Dashy desk hotspots have actually been
///   left empty by the artist for the runtime SwiftUI overlays.
///
/// All reserved-zone rectangles in this file mirror
/// `docs/NOVA-V2-classroom-2.5d-art-contract.md` §3 and the "Required
/// clear visual object zones" sub-section of that document.
///
/// ## Behavior
///
/// - When the environment flag `NOVA_CLASSROOM_HOTSPOTS_DEBUG=1` is set
///   in the running process (typically the Xcode scheme's "Run > Arguments
///   > Environment Variables" pane), the overlay paints a translucent,
///   color-coded rectangle and a small role/title chip per hotspot.
/// - When the flag is absent (the default for every regular install),
///   the view returns `EmptyView()` and contributes nothing — no extra
///   layers, no allocations beyond a single `ProcessInfo` lookup, no
///   accessibility nodes, no draw calls.
///
/// ## Non-goals
///
/// - The overlay does **not** intercept taps. `allowsHitTesting(false)`
///   is set on every visual it draws so the real `ClassroomHotspotButton`
///   underneath still receives touches.
/// - The overlay does **not** alter accessibility for a real user. Every
///   element is `accessibilityHidden(true)`.
/// - The overlay does **not** ship enabled. There is no in-app toggle;
///   the only way to turn it on is the environment variable, and only a
///   developer running through Xcode (or via `xcrun simctl spawn ... env`)
///   has access to set it.
///
/// ## Usage
///
/// Inside a `GeometryReader` that already has a `size: CGSize`, place an
/// `.overlay { ClassroomHotspotDebugOverlay(model: model, size: size) }`
/// (or a sibling layer at `.zIndex(...)` above the hotspots).
public struct ClassroomHotspotDebugOverlay: View {
    private let model: ClassroomSceneModel
    private let size: CGSize

    public init(model: ClassroomSceneModel, size: CGSize) {
        self.model = model
        self.size = size
    }

    /// Read once per init from the process environment. The flag is
    /// intentionally read here (not in `body`) so SwiftUI does not try to
    /// observe it as state — it's a developer toggle, not a user
    /// preference.
    public static var isEnabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["NOVA_CLASSROOM_HOTSPOTS_DEBUG"] == "1"
        #else
        false
        #endif
    }

    public var body: some View {
        if Self.isEnabled {
            enabledOverlay
        } else {
            // Production path: contribute nothing. SwiftUI elides this
            // branch out of the layout tree entirely.
            EmptyView()
        }
    }

    private var enabledOverlay: some View {
        ZStack(alignment: .topLeading) {
            // Reserved zones first so the colored hotspot rectangles
            // render on top — the tap zones are still the primary signal,
            // the reserved zones are scaffolding around them.
            ForEach(ReservedZone.all) { zone in
                let rect = Self.rect(forNormalized: zone.normalizedRect, in: size)
                reservedZoneMarker(zone: zone)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }

            ForEach(model.objects) { object in
                let rect = Self.frame(for: object, in: size)
                hotspotMarker(for: object, color: Self.color(for: object.state))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func hotspotMarker(for object: ClassroomObject, color: Color) -> some View {
        ZStack {
            // Translucent fill — high enough to read against any artwork,
            // low enough to keep the underlying hotspot visible.
            Rectangle()
                .fill(color.opacity(0.22))

            Rectangle()
                .strokeBorder(color, lineWidth: 2)

            // Small label chip that names the hotspot. Kept compact so
            // it does not dominate the overlay; the rectangle itself
            // is the primary signal.
            VStack(spacing: 2) {
                Text(object.title)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(object.role.rawValue)
                    .font(.caption2.monospaced())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.black.opacity(0.72))
            )
            .padding(6)
        }
    }

    /// Mirror of the per-render-path frame math used by
    /// `ClassroomSceneView` and `ClassroomIllustratedSceneView`. Keeps
    /// the 88pt minimum so the visualized rect matches the actual hit
    /// rectangle pixel-for-pixel.
    static func frame(for object: ClassroomObject, in size: CGSize) -> CGRect {
        let width = max(88, object.frame.width * size.width)
        let height = max(88, object.frame.height * size.height)
        let x = object.frame.minX * size.width
        let y = object.frame.minY * size.height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Pixel-space conversion for a normalized rect with no minimum
    /// padding. Used by the reserved-zone overlays — those are *visual*
    /// markers about the artwork, not tap rectangles, so the 88pt floor
    /// from `frame(for:in:)` would distort them.
    static func rect(forNormalized rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: rect.minX * size.width,
            y: rect.minY * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }

    /// Color coding for the three `ClassroomObjectState` cases. Picked
    /// for high contrast against any classroom artwork (red / blue /
    /// gray) — these are debug-only colors and intentionally do *not*
    /// pull from `NovaPalette`, so they cannot be confused with
    /// production UI.
    static func color(for state: ClassroomObjectState) -> Color {
        switch state {
        case .highlighted:
            return .red
        case .available:
            return .blue
        case .disabled:
            return .gray
        }
    }

    // MARK: - Reserved zones

    /// Draws a single reserved zone (Dashy speech-bubble window or a
    /// "this surface must stay clear" mark inside a hotspot). Dashed
    /// border + low-opacity fill so the zone reads as a *constraint*
    /// rather than a tap target.
    private func reservedZoneMarker(zone: ReservedZone) -> some View {
        let stroke = StrokeStyle(lineWidth: 2, dash: [6, 4])
        return ZStack {
            Rectangle()
                .fill(zone.kind.color.opacity(zone.kind.fillOpacity))

            Rectangle()
                .strokeBorder(zone.kind.color, style: stroke)

            VStack(spacing: 2) {
                Text(zone.label)
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(zone.kind.subtitle)
                    .font(.caption2.monospaced())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(zone.kind.color.opacity(0.85))
            )
            .padding(6)
        }
    }
}

// MARK: - ReservedZone

/// A normalized rectangle that the artwork must keep visually calm or
/// fully empty so SwiftUI runtime overlays land cleanly on top. These
/// values mirror `docs/NOVA-V2-classroom-2.5d-art-contract.md` and are
/// intentionally hard-coded here so the debug overlay remains a single,
/// self-contained QA artifact — there is no reason to plumb these into
/// `ClassroomSceneModel` (they are not tap targets).
struct ReservedZone: Identifiable {
    let id: String
    let label: String
    let normalizedRect: CGRect
    let kind: Kind

    enum Kind {
        /// The center column of the scene where the Dashy speech bubble
        /// floats at runtime. Artwork in this band must stay simple.
        case dashyBubble
        /// A surface inside an interactive hotspot (chalkboard slate,
        /// trophy case interior, mission cork face, desk top) that the
        /// artist must leave empty so SwiftUI content can render on it.
        case clearSurface

        var color: Color {
            switch self {
            case .dashyBubble:  return .orange
            case .clearSurface: return .green
            }
        }

        var fillOpacity: Double {
            switch self {
            case .dashyBubble:  return 0.10
            case .clearSurface: return 0.08
            }
        }

        var subtitle: String {
            switch self {
            case .dashyBubble:  return "reserved"
            case .clearSurface: return "clear"
            }
        }
    }

    /// Reserved zones rendered by the debug overlay. Exact values come
    /// from §3 of the art contract.
    static let all: [ReservedZone] = [
        // Center column where the Dashy speech bubble floats.
        ReservedZone(
            id: "dashy-bubble",
            label: "Reserved: Dashy bubble",
            normalizedRect: CGRect(x: 0.30, y: 0.40, width: 0.36, height: 0.25),
            kind: .dashyBubble
        ),
        // Chalkboard slate clear surface — at least 0.40 × 0.22 inside
        // the chalkboard hotspot (which is x=0.22, y=0.07, w=0.46, h=0.30).
        ReservedZone(
            id: "clear-chalkboard",
            label: "Clear: chalkboard slate",
            normalizedRect: CGRect(x: 0.25, y: 0.11, width: 0.40, height: 0.22),
            kind: .clearSurface
        ),
        // Trophy case interior — 0.18 × 0.16 inside the trophy hotspot
        // (x=0.74, y=0.13, w=0.22, h=0.20).
        ReservedZone(
            id: "clear-trophy-interior",
            label: "Clear: trophy interior",
            normalizedRect: CGRect(x: 0.76, y: 0.15, width: 0.18, height: 0.16),
            kind: .clearSurface
        ),
        // Mission board face — 0.20 × 0.18 inside the bulletin hotspot
        // (x=0.72, y=0.40, w=0.24, h=0.22).
        ReservedZone(
            id: "clear-mission-face",
            label: "Clear: mission board",
            normalizedRect: CGRect(x: 0.74, y: 0.42, width: 0.20, height: 0.18),
            kind: .clearSurface
        ),
        // Dashy desk top — 0.20 × 0.08 inside the Dashy desk hotspot
        // (x=0.30, y=0.66, w=0.36, h=0.30). Pinned to the top edge of
        // the desk so it lines up with where things sit on the surface.
        ReservedZone(
            id: "clear-dashy-desk-top",
            label: "Clear: desk top",
            normalizedRect: CGRect(x: 0.38, y: 0.70, width: 0.20, height: 0.08),
            kind: .clearSurface
        ),
    ]
}
