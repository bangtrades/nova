import SwiftUI

/// Celebratory confetti particle animation.
///
/// Shows 50 particles bursting from center with gravity and drift.
/// Duration: 1.5 seconds with opacity fade-out in last 0.3s.
public struct ConfettiView: View {
    @Binding var isActive: Bool

    private let particleCount = 50
    private let duration: Double = 1.5

    @State private var dismissTask: Task<Void, Never>?

    public init(isActive: Binding<Bool>) {
        self._isActive = isActive
    }

    public var body: some View {
        ZStack {
            ForEach(0..<particleCount, id: \.self) { index in
                ConfettiParticle(
                    index: index,
                    particleCount: particleCount,
                    duration: duration,
                    isActive: isActive
                )
            }
        }
        .ignoresSafeArea()
        .onAppear {
            // Schedule auto-dismiss
            dismissTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                isActive = false
            }
        }
        .onDisappear {
            dismissTask?.cancel()
        }
    }
}

/// Individual confetti particle with physics simulation.
private struct ConfettiParticle: View {
    let index: Int
    let particleCount: Int
    let duration: Double
    let isActive: Bool

    @State private var position: CGPoint = .zero
    @State private var opacity: Double = 1.0
    @State private var rotation: Double = 0
    @State private var fadeTask: Task<Void, Never>?

    // Particle properties
    let colors: [Color] = [
        NovaPalette.novaOrange,
        NovaPalette.novaPink,
        NovaPalette.novaBlue,
        NovaPalette.novaGreen,
        NovaPalette.novaPurple,
        NovaPalette.novaYellow
    ]

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.addRect(CGRect(x: -4, y: -4, width: 8, height: 8))

            context.fill(
                path,
                with: .color(colors[index % colors.count])
            )
        }
        .frame(width: 8, height: 8)
        .opacity(opacity)
        .rotationEffect(.degrees(rotation))
        .offset(x: position.x, y: position.y)
        .onAppear {
            if isActive {
                animateParticle()
            }
        }
        .onDisappear {
            fadeTask?.cancel()
        }
    }

    private func animateParticle() {
        let angle = (Double(index) / Double(particleCount)) * .pi * 2
        let speed: Double = 200 + Double.random(in: 0..<100)

        let endX = cos(angle) * speed
        let endY = sin(angle) * speed - (duration * 200) // Gravity effect

        // Slight drift
        let driftX = Double.random(in: -50..<50)

        withAnimation(.easeOut(duration: duration)) {
            position = CGPoint(
                x: endX + driftX,
                y: endY
            )
            rotation = Double.random(in: 0..<360)
        }

        // Fade out in last 0.3s
        fadeTask = Task {
            try? await Task.sleep(nanoseconds: UInt64((duration - 0.3) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 0
            }
        }
    }
}

#Preview {
    @Previewable @State var isActive = true

    return ZStack {
        NovaPalette.novaBackground
            .ignoresSafeArea()

        VStack {
            Text("Confetti!")
                .font(NovaPalette.titleFont())

            Spacer()

            if isActive {
                ConfettiView(isActive: $isActive)
            }

            Spacer()
        }
    }
}
