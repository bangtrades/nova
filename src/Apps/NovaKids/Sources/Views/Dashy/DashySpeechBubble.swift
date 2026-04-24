import SwiftUI

// MARK: - DashySpeechBubble (S11-10)
//
// Reusable comic-book speech bubble used by every Dashy dialogue surface:
// the chat bubble in `DashyView.chatBubble`, the hint panel in
// `DashyHintSheet`, and any future Dashy-authored message container. The
// component is intentionally thin — it's a Shape + fill + stroke + padding
// wrapper around arbitrary content. It doesn't know about text, TTS, or the
// conversation model; callers pass in whatever `Text`/`VStack` they want
// inside the bubble and the bubble handles the paint.
//
// The design intent — documented in SPRINT-11 tracker under S11-10 — is:
//   - `page` fill so the bubble reads as paper in both light and dark modes.
//   - `ink` 2pt stroke so the outline matches the Dashy silhouette weight.
//   - A small triangular tail on one side pointing at the character.
//
// Why a custom `Shape` (vs. `RoundedRectangle` + overlaid triangle Path):
// a single `Shape` means fill + stroke render as one continuous path with
// no visible seam where the tail meets the body. Two-shape composition
// (rect + triangle) always shows a subtle join artifact at 2pt stroke, and
// the artifact becomes prominent under Dynamic Type AX5 where the bubble
// scales up. One shape, one stroke, no seam — this is worth the extra ~30
// lines of path math.

// MARK: - Tail direction

/// Which side of the bubble the tail points from. The tail always points
/// *away* from the bubble body, so `.leading` puts the tail on the left
/// edge pointing further left — i.e. toward a character standing to the
/// left of the bubble.
public enum SpeechBubbleTailSide: Sendable {
    case leading
    case trailing
    /// No tail — use for plain panels that reuse the comic-paper look
    /// without an attached speaker (e.g., Dashy's "Try asking:" panel).
    case none
}

// MARK: - Shape

/// Rounded-rectangle body with an optional triangular tail as a single
/// continuous path.
///
/// - The body is a rounded rect inset from the view bounds on the tail
///   side to leave room for the tail to extrude.
/// - The tail is a small triangle (`tailHeight` × `tailWidth`) whose base
///   sits flush against the body edge, so fill + stroke render seamlessly.
///
/// Designed to be rasterized cheaply — no gradients, no per-frame path
/// recomputation.
public struct SpeechBubbleShape: Shape {
    let cornerRadius: CGFloat
    let tailSide: SpeechBubbleTailSide
    /// How far along the tailed edge the tail sits, `0.0 … 1.0`.
    /// `0.25` places the tail a quarter of the way down the edge (comic-
    /// standard position for a near-top character).
    let tailAnchor: CGFloat
    let tailWidth: CGFloat
    let tailHeight: CGFloat

    public init(
        cornerRadius: CGFloat = 18,
        tailSide: SpeechBubbleTailSide = .leading,
        tailAnchor: CGFloat = 0.35,
        tailWidth: CGFloat = 18,
        tailHeight: CGFloat = 14
    ) {
        self.cornerRadius = cornerRadius
        self.tailSide = tailSide
        self.tailAnchor = tailAnchor
        self.tailWidth = tailWidth
        self.tailHeight = tailHeight
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()

        // Inset the body on the tail side so the tail extends OUT of the
        // body rect rather than overlapping it. Bodies without a tail use
        // the full rect.
        let tailInset: CGFloat = tailSide == .none ? 0 : tailHeight
        let bodyRect: CGRect
        switch tailSide {
        case .leading:
            bodyRect = CGRect(
                x: rect.minX + tailInset,
                y: rect.minY,
                width: rect.width - tailInset,
                height: rect.height
            )
        case .trailing:
            bodyRect = CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width - tailInset,
                height: rect.height
            )
        case .none:
            bodyRect = rect
        }

        // Rounded-rect body. We hand-trace it so we can splice the tail into
        // the perimeter without breaking the path. Order: top-left → top-
        // right → bottom-right → bottom-left, with arcs at each corner.
        let r = min(cornerRadius, min(bodyRect.width, bodyRect.height) / 2)

        path.move(to: CGPoint(x: bodyRect.minX + r, y: bodyRect.minY))

        // Top edge + top-right corner
        path.addLine(to: CGPoint(x: bodyRect.maxX - r, y: bodyRect.minY))
        path.addArc(
            center: CGPoint(x: bodyRect.maxX - r, y: bodyRect.minY + r),
            radius: r,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )

        // Right edge: if tail is trailing, splice the triangle into the
        // middle of the right edge.
        if tailSide == .trailing {
            let tailBaseY = bodyRect.minY + bodyRect.height * tailAnchor
            let tailTopY = tailBaseY - tailWidth / 2
            let tailBotY = tailBaseY + tailWidth / 2
            path.addLine(to: CGPoint(x: bodyRect.maxX, y: tailTopY))
            path.addLine(to: CGPoint(x: bodyRect.maxX + tailHeight, y: tailBaseY))
            path.addLine(to: CGPoint(x: bodyRect.maxX, y: tailBotY))
        }
        path.addLine(to: CGPoint(x: bodyRect.maxX, y: bodyRect.maxY - r))

        // Bottom-right corner + bottom edge
        path.addArc(
            center: CGPoint(x: bodyRect.maxX - r, y: bodyRect.maxY - r),
            radius: r,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: bodyRect.minX + r, y: bodyRect.maxY))

        // Bottom-left corner
        path.addArc(
            center: CGPoint(x: bodyRect.minX + r, y: bodyRect.maxY - r),
            radius: r,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )

        // Left edge: if tail is leading, splice the triangle into the
        // middle of the left edge.
        if tailSide == .leading {
            let tailBaseY = bodyRect.minY + bodyRect.height * tailAnchor
            let tailTopY = tailBaseY + tailWidth / 2 // going UP the left edge
            let tailBotY = tailBaseY - tailWidth / 2
            path.addLine(to: CGPoint(x: bodyRect.minX, y: tailTopY))
            path.addLine(to: CGPoint(x: bodyRect.minX - tailHeight, y: tailBaseY))
            path.addLine(to: CGPoint(x: bodyRect.minX, y: tailBotY))
        }
        path.addLine(to: CGPoint(x: bodyRect.minX, y: bodyRect.minY + r))

        // Top-left corner → back to start
        path.addArc(
            center: CGPoint(x: bodyRect.minX + r, y: bodyRect.minY + r),
            radius: r,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - View

/// Wraps arbitrary content in a paper-fill + ink-stroke speech bubble with
/// an optional tail pointing to a character.
///
/// Usage:
/// ```swift
/// DashySpeechBubble(tailSide: .leading) {
///     Text("Try asking: what is AI?")
///         .font(NovaPalette.bodyFont())
/// }
/// ```
///
/// Padding defaults to `Spacing.md` horizontal / `Spacing.sm + xs` vertical,
/// matching the existing `.cornerRadius(12)` bubbles that were used pre-S11-10.
public struct DashySpeechBubble<Content: View>: View {
    let tailSide: SpeechBubbleTailSide
    let cornerRadius: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let strokeWidth: CGFloat
    @ViewBuilder let content: () -> Content

    public init(
        tailSide: SpeechBubbleTailSide = .leading,
        cornerRadius: CGFloat = 18,
        horizontalPadding: CGFloat = Spacing.md,
        verticalPadding: CGFloat = 12,
        strokeWidth: CGFloat = 2,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.tailSide = tailSide
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.strokeWidth = strokeWidth
        self.content = content
    }

    public var body: some View {
        let shape = SpeechBubbleShape(
            cornerRadius: cornerRadius,
            tailSide: tailSide
        )

        content()
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            // Reserve space on the tailed side so content doesn't sit
            // underneath the tail. This keeps text legible without the
            // bubble body intruding into the tail triangle.
            .padding(.leading, tailSide == .leading ? 6 : 0)
            .padding(.trailing, tailSide == .trailing ? 6 : 0)
            .background(shape.fill(NovaPalette.page))
            .overlay(shape.stroke(NovaPalette.ink, lineWidth: strokeWidth))
    }
}

// MARK: - Preview

#Preview("Speech bubble tails") {
    VStack(spacing: 24) {
        DashySpeechBubble(tailSide: .leading) {
            Text("Hi! I'm Dashy. What should we learn about today?")
                .font(NovaPalette.bodyFont())
                .foregroundStyle(NovaPalette.ink)
        }

        DashySpeechBubble(tailSide: .trailing) {
            Text("Trailing-tail bubble for right-aligned Dashy.")
                .font(NovaPalette.bodyFont())
                .foregroundStyle(NovaPalette.ink)
        }

        DashySpeechBubble(tailSide: .none) {
            VStack(alignment: .leading, spacing: 8) {
                Text("No tail")
                    .font(NovaPalette.smallHeadingFont())
                    .foregroundStyle(NovaPalette.ink)
                Text("Useful for panels that want the paper-and-ink look without a speaker attribution.")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(NovaPalette.ink)
            }
        }
    }
    .padding(Spacing.lg)
    .background(NovaPalette.novaBackground)
}
