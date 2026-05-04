import SwiftUI

/// Placeholder 2D classroom art using Nova v2 classroom material tokens.
public struct ClassroomBackgroundView: View {
    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    NovaPalette.classroomSky.opacity(0.24),
                    NovaPalette.classroomPaper,
                    NovaPalette.classroomWood.opacity(0.22),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                wall
                floor
            }

            window
                .frame(width: 170, height: 120)
                .position(x: 120, y: 110)
                .accessibilityHidden(true)

            rug
                .frame(width: 330, height: 115)
                .position(x: 520, y: 690)
                .accessibilityHidden(true)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var wall: some View {
        Rectangle()
            .fill(NovaPalette.classroomPaper.opacity(0.95))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(NovaPalette.classroomInk.opacity(0.12))
                    .frame(height: 3)
            }
    }

    private var floor: some View {
        Rectangle()
            .fill(NovaPalette.classroomWood.opacity(0.24))
            .overlay {
                VStack(spacing: 18) {
                    ForEach(0..<8, id: \.self) { _ in
                        Rectangle()
                            .fill(NovaPalette.classroomInk.opacity(0.05))
                            .frame(height: 2)
                    }
                }
            }
            .frame(maxHeight: 260)
    }

    private var window: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(NovaPalette.classroomSky.opacity(0.28))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(NovaPalette.classroomInk, lineWidth: 3)
            }
            .overlay {
                HStack(spacing: 0) {
                    Rectangle().fill(NovaPalette.classroomInk).frame(width: 3)
                }
            }
            .overlay {
                VStack(spacing: 0) {
                    Rectangle().fill(NovaPalette.classroomInk).frame(height: 3)
                }
            }
    }

    private var rug: some View {
        Capsule(style: .continuous)
            .fill(NovaPalette.classroomPurple.opacity(0.18))
            .overlay {
                Capsule(style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.35), lineWidth: 2)
            }
    }
}

#Preview {
    ClassroomBackgroundView()
}
