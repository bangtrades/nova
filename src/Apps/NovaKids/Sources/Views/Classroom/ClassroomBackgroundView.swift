import SwiftUI

/// First-person 2D classroom art using Nova v2 classroom material tokens.
public struct ClassroomBackgroundView: View {
    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let horizon = size.height * 0.66

            ZStack {
                wall
                    .frame(height: horizon)
                    .frame(maxHeight: .infinity, alignment: .top)

                wallCornerLines(size: size, horizon: horizon)

                window
                    .frame(width: min(190, size.width * 0.16), height: min(132, size.height * 0.14))
                    .position(x: size.width * 0.11, y: size.height * 0.14)
                    .accessibilityHidden(true)

                garland
                    .frame(width: size.width * 0.46, height: 54)
                    .position(x: size.width * 0.50, y: size.height * 0.055)
                    .accessibilityHidden(true)

                classroomPoster
                    .frame(width: min(190, size.width * 0.16), height: min(142, size.height * 0.15))
                    .position(x: size.width * 0.88, y: size.height * 0.19)
                    .accessibilityHidden(true)

                baseboard
                    .frame(height: 10)
                    .position(x: size.width / 2, y: horizon)
                    .accessibilityHidden(true)

                floor(size: size, horizon: horizon)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)

                frontDeskEdge
                    .frame(width: size.width * 0.82, height: size.height * 0.15)
                    .position(x: size.width * 0.50, y: size.height * 0.94)
                    .accessibilityHidden(true)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var wall: some View {
        LinearGradient(
            colors: [
                NovaPalette.classroomSky.opacity(0.18),
                NovaPalette.classroomPaper,
                NovaPalette.classroomPaper.opacity(0.94)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func wallCornerLines(size: CGSize, horizon: CGFloat) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.22, y: 0))
                path.addLine(to: CGPoint(x: size.width * 0.30, y: horizon))
                path.move(to: CGPoint(x: size.width * 0.78, y: 0))
                path.addLine(to: CGPoint(x: size.width * 0.70, y: horizon))
            }
            .stroke(NovaPalette.classroomInk.opacity(0.06), lineWidth: 2)
        }
    }

    private var baseboard: some View {
        Rectangle()
            .fill(NovaPalette.classroomWood.opacity(0.72))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(NovaPalette.classroomInk.opacity(0.22))
                    .frame(height: 2)
            }
    }

    private func floor(size: CGSize, horizon: CGFloat) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: horizon))
                path.addLine(to: CGPoint(x: size.width, y: horizon))
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [
                        NovaPalette.classroomWood.opacity(0.30),
                        NovaPalette.classroomWood.opacity(0.70)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            ForEach(0..<7, id: \.self) { index in
                let y = horizon + CGFloat(index + 1) * (size.height - horizon) / 7
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(NovaPalette.classroomInk.opacity(0.08), lineWidth: 1)
            }

            ForEach(0..<7, id: \.self) { index in
                let endX = CGFloat(index + 1) * size.width / 8
                Path { path in
                    path.move(to: CGPoint(x: size.width * 0.50, y: horizon))
                    path.addLine(to: CGPoint(x: endX, y: size.height))
                }
                .stroke(NovaPalette.classroomInk.opacity(0.06), lineWidth: 1)
            }
        }
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
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(NovaPalette.classroomSun.opacity(0.45))
                    .frame(width: 38, height: 38)
                    .offset(x: 16, y: 18)
            }
    }

    private var garland: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 10))
                path.addQuadCurve(to: CGPoint(x: 360, y: 10), control: CGPoint(x: 180, y: 70))
            }
            .stroke(NovaPalette.classroomInk.opacity(0.35), lineWidth: 2)

            HStack(spacing: 14) {
                ForEach(0..<9, id: \.self) { index in
                    Circle()
                        .fill(garlandColor(index))
                        .overlay {
                            Circle()
                                .stroke(NovaPalette.classroomInk.opacity(0.35), lineWidth: 1)
                        }
                        .frame(width: 20, height: 20)
                        .offset(y: index.isMultiple(of: 2) ? 18 : 28)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func garlandColor(_ index: Int) -> Color {
        [
            NovaPalette.classroomSchoolRed,
            NovaPalette.classroomSun,
            NovaPalette.classroomLeaf,
            NovaPalette.classroomSky,
            NovaPalette.classroomPurple,
        ][index % 5]
    }

    private var classroomPoster: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(NovaPalette.classroomSchoolRed.opacity(0.18))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.28), lineWidth: 2)
            }
            .overlay {
                VStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(NovaPalette.classroomPaper)
                        .frame(height: 30)
                        .overlay {
                            Image(systemName: "rainbow")
                                .foregroundStyle(NovaPalette.classroomSchoolRed)
                                .accessibilityHidden(true)
                        }
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(garlandColor(index).opacity(0.65))
                                .frame(height: 36)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .padding(14)
            }
    }

    private var frontDeskEdge: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        NovaPalette.classroomWood.opacity(0.86),
                        NovaPalette.classroomWood.opacity(0.66)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(NovaPalette.classroomPaper.opacity(0.18))
                    .frame(height: 3)
                    .padding(.horizontal, 34)
                    .padding(.top, 8)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.24), lineWidth: 2)
            }
            .shadow(color: NovaPalette.classroomInk.opacity(0.20), radius: 18, x: 0, y: -6)
    }
}

#Preview {
    ClassroomBackgroundView()
}
