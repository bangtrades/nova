import SwiftUI

public struct ClassroomObjectButton: View {
    let object: ClassroomObject
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    public init(object: ClassroomObject, action: @escaping () -> Void) {
        self.object = object
        self.action = action
    }

    public var body: some View {
        Button {
            guard object.state != .disabled else { return }
            NovaHaptics.tap()
            action()
        } label: {
            decoratedObjectVisual
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(minWidth: 88, minHeight: 88)
        .scaleEffect(isPressed && !reduceMotion ? 0.96 : 1.0)
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
            .padding(.horizontal, Spacing.xs)
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
        VStack(spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NovaPalette.classroomChalkboard.opacity(0.92))
                .overlay {
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(NovaPalette.classroomSun)
                            .accessibilityHidden(true)
                        Text("Ready")
                            .font(NovaPalette.displayFont(size: 20, relativeTo: .headline))
                            .foregroundStyle(NovaPalette.classroomChalkDust)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
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
        }
        .padding(Spacing.sm)
    }

    private var bookshelf: some View {
        VStack(spacing: Spacing.xs) {
            HStack(alignment: .bottom, spacing: Spacing.xs) {
                book(NovaPalette.classroomSchoolRed, height: 58)
                book(NovaPalette.classroomSky, height: 76)
                book(NovaPalette.classroomSun, height: 66)
                book(NovaPalette.classroomPurple, height: 84)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(NovaPalette.classroomWood.opacity(0.30))
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(NovaPalette.classroomWood)
                    .frame(height: 3)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.bottom, Spacing.sm)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(NovaPalette.classroomInk, lineWidth: 3)
            }
            title
        }
        .padding(Spacing.sm)
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
        VStack(spacing: Spacing.xs) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(NovaPalette.classroomWood.opacity(0.45))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(NovaPalette.classroomInk, lineWidth: 3)
                    }
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
                .frame(height: 48)
                .padding(Spacing.md)
            }
            title
        }
        .padding(Spacing.sm)
    }

    private var dashyDesk: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(NovaPalette.classroomPurple.opacity(0.22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(NovaPalette.classroomInk, lineWidth: 3)
                    }
                VStack(spacing: Spacing.xs) {
                    Circle()
                        .fill(NovaPalette.classroomSun)
                        .overlay(Circle().stroke(NovaPalette.classroomInk, lineWidth: 2))
                        .frame(width: 54, height: 54)
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundStyle(NovaPalette.classroomPurple)
                        .accessibilityHidden(true)
                }
            }
            title
        }
        .padding(Spacing.sm)
    }

    private var trophyShelf: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(NovaPalette.classroomWood.opacity(0.28))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(NovaPalette.classroomInk, lineWidth: 3)
                    }
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "trophy.fill")
                    Image(systemName: "star.circle.fill")
                    Image(systemName: "rosette")
                }
                .font(.title2)
                .foregroundStyle(
                    NovaPalette.classroomSun,
                    NovaPalette.classroomSchoolRed
                )
                .accessibilityHidden(true)
            }
            title
        }
        .padding(Spacing.sm)
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
                        pinnedNote(
                            color: NovaPalette.classroomPaper,
                            rotation: -7,
                            icon: "sparkles"
                        )
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

#Preview {
    ClassroomObjectButton(
        object: ClassroomSceneModel.home(currentLessonId: UUID()).objects[0],
        action: {}
    )
    .frame(width: 260, height: 180)
    .background(NovaPalette.novaBackground)
}
