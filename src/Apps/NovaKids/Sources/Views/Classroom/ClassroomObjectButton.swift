import SwiftUI
import UIKit
import NovaClassroom

public struct ClassroomObjectButton: View {
    let object: ClassroomObject
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    @State private var tapBurst = 0

    public init(object: ClassroomObject, action: @escaping () -> Void) {
        self.object = object
        self.action = action
    }

    public var body: some View {
        Button {
            guard object.state != .disabled else { return }
            NovaHaptics.tap()
            tapBurst += 1
            action()
        } label: {
            decoratedObjectVisual
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(minWidth: 88, minHeight: 88)
        // V2-S4-05: sparkle burst on tap — third beat of the reaction
        // triple (bounce + haptic + burst). No-op under Reduce Motion.
        .overlay {
            ClassroomTapBurst(trigger: tapBurst)
        }
        .scaleEffect(isPressed && reduceMotion == false ? 0.96 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.72), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .opacity(object.state == .disabled ? 0.72 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(object.accessibilityLabel)
        .accessibilityValue(accessibilityStateValue)
        .accessibilityHint(object.accessibilityHint)
        .accessibilityAddTraits(object.state == .disabled ? [] : .isButton)
    }

    private var decoratedObjectVisual: some View {
        objectVisual
            .saturation(object.state == .disabled ? 0.70 : 1.0)
            .overlay(alignment: .topTrailing) {
                if object.state == .highlighted {
                    highlightedBadge
                        .padding(Spacing.xs)
                } else if object.role == .trophyShelf, let text = object.badgeText {
                    countBadge(text: text)
                        .padding(Spacing.xs)
                }
            }
            .overlay(alignment: .topLeading) {
                if object.state == .disabled {
                    disabledBadge
                        .padding(Spacing.xs)
                }
            }
            .overlay {
                if object.state == .disabled {
                    disabledVeil
                }
            }
    }

    /// Sun-tinted sticker shown on the trophy shelf when the active child has
    /// at least one trophy. Mirrors `highlightedBadge` styling so the rail of
    /// classroom objects shares one badge family — one star icon, paper-strap
    /// capsule, ink stroke, soft drop-shadow.
    private func countBadge(text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.caption2.weight(.bold))
                .accessibilityHidden(true)
            Text(text)
                .font(NovaPalette.captionFont().weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(NovaPalette.classroomInk)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule(style: .continuous)
                .fill(NovaPalette.classroomSun)
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(NovaPalette.classroomInk, lineWidth: 1.5)
        }
        .shadow(color: NovaPalette.classroomInk.opacity(0.16), radius: 2, x: 0, y: 1)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var objectVisual: some View {
        switch object.role {
        case .chalkboard:
            chalkboard
        case .bookshelf:
            bookshelf
        case .projectTable:
            projectTable
        case .dashyDesk:
            dashyDesk
        case .trophyShelf:
            trophyShelf
        case .backpack:
            backpack
        case .bulletinBoard:
            bulletinBoard
        case .generatedLesson:
            generatedLesson
        }
    }

    private var cornerRadius: CGFloat {
        switch object.role {
        case .chalkboard, .bookshelf, .projectTable, .dashyDesk, .trophyShelf:
            return 18
        case .backpack, .bulletinBoard, .generatedLesson:
            return 22
        }
    }

    private var title: some View {
        Text(object.title)
            .font(NovaPalette.captionFont().weight(.bold))
            .foregroundStyle(NovaPalette.classroomInk)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(NovaPalette.classroomPaper.opacity(0.90))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.45), lineWidth: 1)
            }
    }

    private var highlightedStroke: Color {
        object.state == .highlighted ? NovaPalette.classroomSchoolRed : NovaPalette.classroomInk
    }

    private var accessibilityStateValue: String {
        switch object.state {
        case .available:
            return ""
        case .highlighted:
            return "Ready to tap"
        case .disabled:
            return "Coming soon"
        }
    }

    private var highlightedBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.caption2.weight(.bold))
                .accessibilityHidden(true)
            Text("Tap")
                .font(NovaPalette.captionFont().weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(NovaPalette.classroomInk)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule(style: .continuous)
                .fill(NovaPalette.classroomSun)
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(NovaPalette.classroomInk, lineWidth: 1.5)
        }
        .shadow(color: NovaPalette.classroomInk.opacity(0.16), radius: 2, x: 0, y: 1)
        .accessibilityHidden(true)
    }

    private var disabledBadge: some View {
        Text("Soon")
            .font(NovaPalette.captionFont().weight(.bold))
            .foregroundStyle(NovaPalette.classroomInk)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule(style: .continuous)
                    .fill(NovaPalette.classroomPaper.opacity(0.92))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.75), lineWidth: 1.5)
            }
            .accessibilityHidden(true)
    }

    private var disabledVeil: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                NovaPalette.classroomPaper.opacity(0.78),
                style: StrokeStyle(lineWidth: 3, dash: [7, 5])
            )
            .padding(Spacing.xs)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var chalkboard: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NovaPalette.classroomChalkboard.opacity(0.92))
                .overlay {
                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "sparkles")
                            .font(.title)
                            .foregroundStyle(NovaPalette.classroomSun)
                            .accessibilityHidden(true)
                        Text(object.state == .highlighted ? "Ready" : "Today")
                            .font(NovaPalette.displayFont(size: 24, relativeTo: .headline))
                            .foregroundStyle(NovaPalette.classroomChalkDust)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .overlay(alignment: .bottom) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(NovaPalette.classroomChalkDust.opacity(0.75))
                            .frame(width: 62, height: 5)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(NovaPalette.classroomSchoolRed.opacity(0.88))
                            .frame(width: 32, height: 7)
                    }
                    .padding(.bottom, 10)
                    .accessibilityHidden(true)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(highlightedStroke, lineWidth: object.state == .highlighted ? 4 : 3)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(NovaPalette.classroomWood, lineWidth: 2)
                        .padding(3)
                }

            title
                .offset(y: 13)
        }
        .padding(Spacing.sm)
    }

    private var bookshelf: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NovaPalette.classroomWood.opacity(0.34))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(NovaPalette.classroomInk, lineWidth: 3)
                }
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(NovaPalette.classroomWood.opacity(0.70))
                        .frame(width: 12)
                        .padding(.vertical, Spacing.sm)
                        .padding(.leading, Spacing.sm)
                }
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(NovaPalette.classroomWood.opacity(0.70))
                        .frame(width: 12)
                        .padding(.vertical, Spacing.sm)
                        .padding(.trailing, Spacing.sm)
                }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(NovaPalette.classroomWood)
                    .frame(height: 5)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.bottom, Spacing.sm)
            }
            .overlay {
                VStack(spacing: Spacing.md) {
                    shelfRow(heights: [44, 64, 54, 70])
                    shelfRow(heights: [60, 48, 72])
                    shelfRow(heights: [42, 56, 46, 68])
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
            }

            title
                .offset(y: 12)
        }
        .padding(Spacing.sm)
    }

    private func shelfRow(heights: [CGFloat]) -> some View {
        VStack(spacing: 5) {
            HStack(alignment: .bottom, spacing: Spacing.xs) {
                ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                    book(bookColor(index), height: height)
                }
                Spacer(minLength: 0)
            }
            Rectangle()
                .fill(NovaPalette.classroomInk.opacity(0.65))
                .frame(height: 2)
        }
        .accessibilityHidden(true)
    }

    private func bookColor(_ index: Int) -> Color {
        [
            NovaPalette.classroomSchoolRed,
            NovaPalette.classroomSky,
            NovaPalette.classroomSun,
            NovaPalette.classroomPurple,
            NovaPalette.classroomLeaf,
        ][index % 5]
    }

    private func book(_ color: Color, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(color)
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(NovaPalette.classroomInk, lineWidth: 2)
            }
            .frame(width: 24, height: height)
            .accessibilityHidden(true)
    }

    private var projectTable: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(NovaPalette.classroomWood.opacity(0.42))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(NovaPalette.classroomInk.opacity(0.75), lineWidth: 3)
                }
                .overlay(alignment: .top) {
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(NovaPalette.classroomSky)
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(NovaPalette.classroomSun)
                        Circle()
                            .fill(NovaPalette.classroomSchoolRed)
                    }
                    .overlay {
                        HStack(spacing: Spacing.sm) {
                            Circle().stroke(NovaPalette.classroomInk, lineWidth: 2)
                            RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(NovaPalette.classroomInk, lineWidth: 2)
                            Circle().stroke(NovaPalette.classroomInk, lineWidth: 2)
                        }
                    }
                    .frame(height: 36)
                    .padding(Spacing.md)
                    .accessibilityHidden(true)
                }

            HStack(spacing: Spacing.xl) {
                Rectangle()
                    .fill(NovaPalette.classroomInk.opacity(0.50))
                    .frame(width: 6, height: 34)
                Rectangle()
                    .fill(NovaPalette.classroomInk.opacity(0.50))
                    .frame(width: 6, height: 34)
            }
            .offset(y: 18)
            .accessibilityHidden(true)

            title
                .offset(y: 12)
        }
        .padding(Spacing.sm)
    }

    private var dashyDesk: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            NovaPalette.classroomWood.opacity(0.82),
                            NovaPalette.classroomWood.opacity(0.58)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(NovaPalette.classroomInk, lineWidth: 3)
                }
                .overlay(alignment: .topLeading) {
                    pencilCup
                        .frame(width: 70, height: 70)
                        .padding(.leading, Spacing.lg)
                        .padding(.top, Spacing.md)
                        .accessibilityHidden(true)
                }
                .overlay(alignment: .topTrailing) {
                    dashyFace
                        .frame(width: 78, height: 78)
                        .padding(.trailing, Spacing.xl)
                        .padding(.top, Spacing.sm)
                        .accessibilityHidden(true)
                }
                .overlay {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title)
                        .foregroundStyle(NovaPalette.classroomPurple)
                        .padding(.top, 28)
                        .accessibilityHidden(true)
                }

            title
                .offset(y: -10)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.sm)
    }

    private var pencilCup: some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 4) {
                Rectangle()
                    .fill(NovaPalette.classroomSchoolRed)
                    .frame(width: 8, height: 52)
                    .rotationEffect(.degrees(-10))
                Rectangle()
                    .fill(NovaPalette.classroomSun)
                    .frame(width: 8, height: 60)
                Rectangle()
                    .fill(NovaPalette.classroomSky)
                    .frame(width: 8, height: 48)
                    .rotationEffect(.degrees(10))
            }
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(NovaPalette.classroomPurple.opacity(0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(NovaPalette.classroomInk, lineWidth: 2)
                }
                .frame(width: 52, height: 34)
        }
    }

    private var dashyFace: some View {
        Circle()
            .fill(NovaPalette.classroomSun)
            .overlay(Circle().stroke(NovaPalette.classroomInk, lineWidth: 2))
            .overlay {
                VStack(spacing: 7) {
                    HStack(spacing: 14) {
                        Circle()
                            .fill(NovaPalette.classroomInk)
                            .frame(width: 7, height: 7)
                        Circle()
                            .fill(NovaPalette.classroomInk)
                            .frame(width: 7, height: 7)
                    }
                    Capsule(style: .continuous)
                        .stroke(NovaPalette.classroomSchoolRed, lineWidth: 2)
                        .frame(width: 28, height: 12)
                        .mask(alignment: .bottom) {
                            Rectangle()
                                .frame(height: 7)
                        }
                }
            }
    }

    private var trophyShelf: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NovaPalette.classroomSky.opacity(0.16))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(NovaPalette.classroomWood, lineWidth: 6)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(NovaPalette.classroomInk, lineWidth: 2)
                        .padding(5)
                }
                .overlay {
                    VStack(spacing: Spacing.sm) {
                        HStack(spacing: Spacing.md) {
                            trophyIcon(size: 26)
                            Image(systemName: "star.circle.fill")
                                .font(.title2)
                                .foregroundStyle(NovaPalette.classroomSchoolRed)
                            Image(systemName: "rosette")
                                .font(.title2)
                                .foregroundStyle(NovaPalette.classroomSun)
                        }
                        Rectangle()
                            .fill(NovaPalette.classroomWood)
                            .frame(height: 3)
                            .padding(.horizontal, Spacing.md)
                    }
                    .accessibilityHidden(true)
                }

            title
                .offset(y: 12)
        }
        .padding(Spacing.sm)
    }

    private func trophyIcon(size: CGFloat) -> some View {
        Image(systemName: "trophy.fill")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(NovaPalette.classroomSun)
            .shadow(color: NovaPalette.classroomInk.opacity(0.18), radius: 2, y: 1)
    }

    private var backpack: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "backpack.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(NovaPalette.classroomSky)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(NovaPalette.classroomPurple.opacity(0.12))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(NovaPalette.classroomInk, lineWidth: 3)
                }
                .accessibilityHidden(true)
            title
        }
        .padding(Spacing.sm)
    }

    private var bulletinBoard: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(NovaPalette.classroomWood.opacity(0.46))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(highlightedStroke, lineWidth: object.state == .highlighted ? 4 : 3)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(NovaPalette.classroomInk.opacity(0.55), lineWidth: 2)
                            .padding(Spacing.xs)
                    }

                VStack(spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        // First pin uses the painted yellow hint-note
                        // sticker when the asset is in the bundle.
                        // Falls back to the SwiftUI pinned-note shape
                        // so the bulletin board still reads as a
                        // pin-board when the asset is missing.
                        if UIImage(named: "lesson_hint_note_45") != nil {
                            paintedHintPin(rotation: -7)
                        } else {
                            pinnedNote(
                                color: NovaPalette.classroomPaper,
                                rotation: -7,
                                icon: "sparkles"
                            )
                        }

                        pinnedNote(
                            color: NovaPalette.classroomSun,
                            rotation: 6,
                            icon: "star.fill"
                        )
                    }

                    Text("New")
                        .font(NovaPalette.displayFont(size: 16, relativeTo: .caption))
                        .foregroundStyle(NovaPalette.classroomInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(NovaPalette.classroomSchoolRed.opacity(0.86))
                        )
                        .overlay {
                            Capsule(style: .continuous)
                                .stroke(NovaPalette.classroomInk, lineWidth: 1.5)
                        }
                }
                .padding(Spacing.sm)
            }
            title
        }
        .padding(Spacing.sm)
    }

    /// Painted hint-note sticker pinned to the cork. Used by the
    /// bulletin board to ground the mission-board art with one
    /// painted note alongside the SwiftUI-drawn star note. Falls
    /// through to `pinnedNote` when the asset is unavailable.
    private func paintedHintPin(rotation: Double) -> some View {
        ZStack(alignment: .top) {
            Image("lesson_hint_note_45")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .accessibilityHidden(true)

            // Thumbtack on top so the painted note still reads as
            // pinned to the cork (the painted asset has no tack).
            Circle()
                .fill(NovaPalette.classroomSchoolRed)
                .overlay {
                    Circle()
                        .stroke(NovaPalette.classroomInk, lineWidth: 1)
                }
                .frame(width: 10, height: 10)
                .offset(y: -4)
        }
        .frame(width: 36, height: 42)
        .rotationEffect(.degrees(rotation))
        .accessibilityHidden(true)
    }

    private func pinnedNote(color: Color, rotation: Double, icon: String) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color)
            .overlay(alignment: .top) {
                Circle()
                    .fill(NovaPalette.classroomSchoolRed)
                    .overlay {
                        Circle()
                            .stroke(NovaPalette.classroomInk, lineWidth: 1)
                    }
                    .frame(width: 10, height: 10)
                    .offset(y: -4)
            }
            .overlay {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NovaPalette.classroomInk)
                    .accessibilityHidden(true)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(NovaPalette.classroomInk, lineWidth: 1.5)
            }
            .frame(width: 36, height: 42)
            .rotationEffect(.degrees(rotation))
            .accessibilityHidden(true)
    }

    private var generatedLesson: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(NovaPalette.classroomPurple.opacity(0.26))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(highlightedStroke, lineWidth: object.state == .highlighted ? 4 : 3)
                    }

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(NovaPalette.classroomPaper)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(NovaPalette.classroomInk, lineWidth: 2)
                    }
                    .padding(Spacing.sm)

                VStack(spacing: Spacing.xs) {
                    ZStack {
                        Circle()
                            .fill(NovaPalette.classroomSun)
                            .overlay {
                                Circle()
                                    .stroke(NovaPalette.classroomInk, lineWidth: 2)
                            }
                        Image(systemName: "sparkles")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(NovaPalette.classroomPurple)
                            .accessibilityHidden(true)
                    }
                    .frame(width: 44, height: 44)

                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(index == 1 ? NovaPalette.classroomSchoolRed : NovaPalette.classroomPurple)
                                .frame(width: 7, height: 7)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .padding(Spacing.md)
            }
            title
        }
        .padding(Spacing.sm)
    }

    private var genericObject: some View {
        VStack(spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(NovaPalette.classroomObjectColor(for: object.role.rawValue).opacity(0.22))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(NovaPalette.classroomInk, lineWidth: 3)
                }
            title
        }
        .padding(Spacing.sm)
    }
}

// MARK: - Tap burst (V2-S4-05)

/// Small sparkle burst fired when a kid taps a primary classroom object
/// (V2-S4-05).
///
/// Completes the story's reaction triple — bounce (`scaleEffect` spring
/// on the buttons), haptic (`NovaHaptics.tap()`), and **this**: a brief
/// spray of classroom-palette sparkles from the center of the tapped
/// object. The burst is the same in both render paths (shape-fallback
/// `ClassroomObjectButton` and illustrated `ClassroomHotspotButton`) so
/// the tap reaction stays consistent when final art lands.
///
/// Lives in this file rather than its own because adding a file to the
/// NovaKids target requires an Xcode-side pbxproj registration (project
/// rule: new files via Xcode UI only). Split it out on the next Xcode
/// pass if preferred.
///
/// ## Behavior
///
/// The parent owns an `Int` trigger and increments it on tap. Each
/// change plays one ~0.55s cycle: eight particles (six palette dots,
/// two sparkle glyphs) spring out radially from the center, shrinking
/// and fading as they travel. The spray view is removed from the
/// hierarchy entirely once the cycle ends — zero idle cost.
///
/// ## Reduce Motion
///
/// Renders **nothing** when Reduce Motion is on. The story's acceptance
/// criterion is explicit — "Reduced motion removes ambient and particle
/// effects" — and the haptic + the button's static state change already
/// confirm the tap without motion.
///
/// ## Accessibility
///
/// `accessibilityHidden(true)` and hit-testing disabled — the burst is
/// pure decoration; VoiceOver users get the button's label + haptic.
struct ClassroomTapBurst: View {
    /// Increment to fire one burst. Monotonic counter, not a Bool, so
    /// rapid re-taps restart the spray instead of getting swallowed.
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeBurst: Int?
    @State private var clearTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if let id = activeBurst {
                BurstSpray()
                    .id(id) // new identity per tap → onAppear re-runs
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, newValue in
            guard !reduceMotion else { return }
            activeBurst = newValue
            clearTask?.cancel()
            clearTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 650_000_000)
                guard !Task.isCancelled else { return }
                activeBurst = nil
            }
        }
        .onDisappear {
            clearTask?.cancel()
        }
    }
}

/// One spray cycle. Created fresh per burst (the parent re-`id`s it) so
/// all animation state starts from the pre-burst pose.
private struct BurstSpray: View {
    @State private var flying = false

    /// Fixed particle layout — evenly spaced angles with a small
    /// per-index jitter so the spray reads organic without per-tap
    /// randomness (deterministic renders, stable previews).
    private struct Particle {
        let angle: Double      // degrees
        let distance: CGFloat  // points traveled at full flight
        let size: CGFloat
        let color: Color
        let isSparkle: Bool
    }

    private static let palette: [Color] = [
        NovaPalette.classroomSun,
        NovaPalette.classroomSky,
        NovaPalette.classroomSchoolRed,
        NovaPalette.classroomLeaf,
        NovaPalette.classroomPurple,
    ]

    private static let particles: [Particle] = (0..<8).map { index in
        let jitter = [4.0, -7.0, 6.0, -3.0, 8.0, -5.0, 2.0, -6.0][index]
        return Particle(
            angle: Double(index) * 45.0 + jitter,
            distance: [38, 30, 42, 32, 40, 28, 36, 34][index],
            size: [7, 5, 8, 5, 7, 5, 6, 5][index],
            color: palette[index % palette.count],
            isSparkle: index % 4 == 0 // two sparkle glyphs in the eight
        )
    }

    var body: some View {
        ZStack {
            ForEach(Array(Self.particles.enumerated()), id: \.offset) { _, particle in
                particleView(particle)
                    .offset(
                        x: flying ? cos(particle.angle * .pi / 180) * particle.distance : 0,
                        y: flying ? sin(particle.angle * .pi / 180) * particle.distance : 0
                    )
                    .scaleEffect(flying ? 0.35 : 1.0)
                    .opacity(flying ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) {
                flying = true
            }
        }
    }

    @ViewBuilder
    private func particleView(_ particle: Particle) -> some View {
        if particle.isSparkle {
            Image(systemName: "sparkle")
                .font(.system(size: particle.size + 4, weight: .bold))
                .foregroundStyle(particle.color)
        } else {
            Circle()
                .fill(particle.color)
                .frame(width: particle.size, height: particle.size)
        }
    }
}

#Preview {
    ClassroomObjectButton(
        object: ClassroomSceneModel.home(currentLessonId: UUID()).objects[0],
        action: {}
    )
    .frame(width: 260, height: 180)
    .background(NovaPalette.novaBackground)
}
