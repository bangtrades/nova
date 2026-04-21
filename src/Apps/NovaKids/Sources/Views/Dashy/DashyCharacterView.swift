import SwiftUI

/// Animation state for Dashy character expression.
public enum DashyAnimationState {
    case idle
    case listening
    case thinking
    case talking
    case celebrating
}

/// Reusable animated Dashy character component with expression states.
///
/// Draws a cute robot face with animated eyes, mouth, and antenna.
/// Changes expression based on the animation state binding.
public struct DashyCharacterView: View {
    @Binding var state: DashyAnimationState

    @State private var blinkOpacity: Double = 1.0
    @State private var antennaRotation: Double = 0
    @State private var mouthScale: Double = 1.0
    @State private var bobOffset: Double = 0
    @State private var pulseScale: Double = 1.0
    @State private var rotationAngle: Double = 0
    @State private var celebrationScale: Double = 1.0
    @State private var blinkTimer: Timer? = nil
    @State private var blinkTask: Task<Void, Never>?

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    public init(state: Binding<DashyAnimationState>) {
        self._state = state
    }

    public var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let characterSize = size * 0.6

            ZStack {
                // Listening/Thinking rings
                if state == .listening || state == .thinking {
                    pulseRings(size: characterSize * 1.3)
                }

                // Celebrating particles
                if state == .celebrating {
                    celebrationParticles()
                }

                VStack(spacing: 0) {
                    // Antenna
                    antennaView(size: characterSize * 0.15)
                        .offset(y: -characterSize * 0.35)
                        .rotationEffect(.degrees(antennaRotation))

                    // Character body (circle)
                    ZStack {
                        // Background gradient
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        NovaPalette.novaPurple,
                                        NovaPalette.novaBlue
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: characterSize, height: characterSize)

                        // Face
                        VStack(spacing: characterSize * 0.12) {
                            // Eyes
                            HStack(spacing: characterSize * 0.15) {
                                eyeView(size: characterSize * 0.15)
                                eyeView(size: characterSize * 0.15)
                            }
                            .opacity(blinkOpacity)

                            Spacer()

                            // Mouth
                            mouthView(size: characterSize * 0.2)
                        }
                        .padding(characterSize * 0.15)
                        .frame(width: characterSize, height: characterSize)
                    }
                    .scaleEffect(state == .celebrating ? celebrationScale : 1.0)
                    .offset(y: state == .idle ? bobOffset : 0)
                }
                .frame(width: size, height: size, alignment: .center)
            }
            .onAppear {
                setupAnimations()
            }
            .onChange(of: state) {
                resetAnimations()
                setupAnimations()
            }
            .onDisappear {
                blinkTimer?.invalidate()
                blinkTimer = nil
                blinkTask?.cancel()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Subviews

    private func eyeView(size: CGFloat) -> some View {
        ZStack {
            // Eye white
            Capsule()
                .fill(Color.white)

            // Pupil
            Circle()
                .fill(Color.black)
                .frame(width: size * 0.5, height: size * 0.5)
                .offset(x: eyeOffset().x, y: eyeOffset().y)
        }
        .frame(width: size, height: size * 1.2)
    }

    private func eyeOffset() -> (x: CGFloat, y: CGFloat) {
        switch state {
        case .idle, .listening, .talking:
            return (x: 0, y: 0)
        case .thinking:
            // Look up and to the right
            return (x: 2, y: -2)
        case .celebrating:
            // Happy squint
            return (x: 0, y: 0)
        }
    }

    private func mouthView(size: CGFloat) -> some View {
        ZStack {
            if state == .celebrating {
                // Happy squint smile
                Path { path in
                    path.addArc(
                        center: CGPoint(x: size / 2, y: size / 2),
                        radius: size / 2,
                        startAngle: .degrees(0),
                        endAngle: .degrees(180),
                        clockwise: false
                    )
                }
                .stroke(Color.black, lineWidth: 3)
            } else {
                // Normal smile or neutral
                Path { path in
                    path.addArc(
                        center: CGPoint(x: size / 2, y: size / 2),
                        radius: size / 2,
                        startAngle: .degrees(0),
                        endAngle: .degrees(180),
                        clockwise: false
                    )
                }
                .stroke(Color.black, lineWidth: 2)
            }
        }
        .frame(width: size, height: size * 0.6)
        .scaleEffect(mouthScale, anchor: .center)
    }

    private func antennaView(size: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Antenna rod
            Rectangle()
                .fill(Color.black)
                .frame(width: size * 0.4, height: size * 3)

            // Antenna ball
            Circle()
                .fill(NovaPalette.novaYellow)
                .frame(width: size * 1.5, height: size * 1.5)
        }
    }

    private func pulseRings(size: CGFloat) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                NovaPalette.novaBlue.opacity(0.6),
                                NovaPalette.novaPurple.opacity(0.2)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: size * (1 + CGFloat(index) * 0.3), height: size * (1 + CGFloat(index) * 0.3))
                    .scaleEffect(pulseScale)
                    .opacity(1 - Double(index) * 0.3)
            }
        }
    }

    private func celebrationParticles() -> some View {
        ZStack {
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        [
                            NovaPalette.novaYellow,
                            NovaPalette.novaOrange,
                            NovaPalette.novaPink,
                            NovaPalette.novaGreen,
                            NovaPalette.novaBlue,
                            NovaPalette.novaPurple
                        ][index]
                    )
                    .frame(width: 8, height: 8)
                    .offset(
                        x: CGFloat(cos(Double(index) * .pi / 3)) * 40,
                        y: CGFloat(sin(Double(index) * .pi / 3)) * 40
                    )
            }
        }
    }

    // MARK: - Animations

    private func setupAnimations() {
        switch state {
        case .idle:
            animateIdle()
        case .listening:
            animateListening()
        case .thinking:
            animateThinking()
        case .talking:
            animateTalking()
        case .celebrating:
            animateCelebrating()
        }
    }

    private func resetAnimations() {
        blinkOpacity = 1.0
        antennaRotation = 0
        mouthScale = 1.0
        bobOffset = 0
        pulseScale = 1.0
        rotationAngle = 0
        celebrationScale = 1.0
    }

    private func animateIdle() {
        // Gentle bobbing
        if !reduceMotion {
            withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                bobOffset = 8
            }
        }

        // Occasional blink
        if !reduceMotion {
            blinkTimer?.invalidate()
            blinkTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [self] _ in
                Task { @MainActor in
                    withAnimation(Animation.easeInOut(duration: 0.15)) {
                        blinkOpacity = 0
                    }
                    blinkTask?.cancel()
                    blinkTask = Task {
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        guard !Task.isCancelled else { return }
                        withAnimation(Animation.easeInOut(duration: 0.15)) {
                            blinkOpacity = 1.0
                        }
                    }
                }
            }
        }
    }

    private func animateListening() {
        // Pulse rings
        if !reduceMotion {
            withAnimation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pulseScale = 1.3
            }

            // Wiggle antenna
            withAnimation(Animation.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                antennaRotation = 10
            }
        }

        // Keep eyes alert
        blinkOpacity = 1.0
    }

    private func animateThinking() {
        if !reduceMotion {
            // Rotating dots around character
            withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }

            // Antenna tilt
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                antennaRotation = -15
            }
        }
    }

    private func animateTalking() {
        if !reduceMotion {
            // Mouth bounce synced to speech
            withAnimation(Animation.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                mouthScale = 1.2
            }

            // Head bobbing
            withAnimation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                bobOffset = 5
            }
        }
    }

    private func animateCelebrating() {
        if !reduceMotion {
            // Scale bounce
            withAnimation(
                Animation
                    .spring(response: 0.6, dampingFraction: 0.6)
                    .repeatForever(autoreverses: true)
            ) {
                celebrationScale = 1.15
            }

            // Antenna wild wiggle
            withAnimation(Animation.easeInOut(duration: 0.2).repeatForever(autoreverses: true)) {
                antennaRotation = 20
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        HStack(spacing: 20) {
            VStack(spacing: 8) {
                DashyCharacterView(state: .constant(.idle))
                Text("Idle")
                    .font(NovaPalette.captionFont())
            }

            VStack(spacing: 8) {
                DashyCharacterView(state: .constant(.listening))
                Text("Listening")
                    .font(NovaPalette.captionFont())
            }

            VStack(spacing: 8) {
                DashyCharacterView(state: .constant(.thinking))
                Text("Thinking")
                    .font(NovaPalette.captionFont())
            }
        }

        HStack(spacing: 20) {
            VStack(spacing: 8) {
                DashyCharacterView(state: .constant(.talking))
                Text("Talking")
                    .font(NovaPalette.captionFont())
            }

            VStack(spacing: 8) {
                DashyCharacterView(state: .constant(.celebrating))
                Text("Celebrating")
                    .font(NovaPalette.captionFont())
            }
        }
    }
    .padding(30)
    .background(NovaPalette.novaBackground)
}
