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
                    //
                    // S11-10 reskin: comic-book Dashy.
                    //   - Body: solid `sun` fill (3+1 palette, the "Dashy body" token).
                    //   - Silhouette: 2pt `ink` strokeBorder for comic-line feel.
                    //   - Cheeks: two small `coral` half-discs flanking the mouth —
                    //     this is where the 3+1's coral accent lands on the character.
                    //
                    // We keep the body as a single `Circle` shape (no geometry
                    // change) so every animation hook — bobOffset, celebrationScale,
                    // state-driven offsets — keeps firing exactly as before. Paint
                    // only, no rigging.
                    ZStack {
                        // Body fill
                        Circle()
                            .fill(NovaPalette.sun)
                            .frame(width: characterSize, height: characterSize)
                            .overlay(
                                // Comic silhouette — strokeBorder keeps the 2pt line
                                // inside the body radius so the visible shape doesn't
                                // grow compared to the pre-stroke layout.
                                Circle()
                                    .strokeBorder(NovaPalette.ink, lineWidth: 2)
                                    .frame(width: characterSize, height: characterSize)
                            )

                        // Face
                        VStack(spacing: characterSize * 0.12) {
                            // Eyes
                            HStack(spacing: characterSize * 0.15) {
                                eyeView(size: characterSize * 0.15)
                                eyeView(size: characterSize * 0.15)
                            }
                            .opacity(blinkOpacity)

                            Spacer()

                            // Mouth with coral cheeks. Cheeks sit *behind* the
                            // mouth arc at the same vertical band, flanking it
                            // left and right. They pin to the character size so
                            // Dynamic Type-independent geometry holds.
                            ZStack {
                                HStack(spacing: characterSize * 0.32) {
                                    cheekView(size: characterSize * 0.12)
                                    cheekView(size: characterSize * 0.12)
                                }
                                mouthView(size: characterSize * 0.2)
                            }
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
        // Flatten the whole character into one VoiceOver element so the
        // ring / particle / face subviews don't each announce individually.
        // State is surfaced as a value so swiping to Dashy reads e.g.
        // "Dashy, listening."
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Dashy")
        .accessibilityValue(accessibilityStateLabel)
        .accessibilityAddTraits(.isImage)
    }

    /// Human-readable state label for VoiceOver.
    private var accessibilityStateLabel: String {
        switch state {
        case .idle: return "idle"
        case .listening: return "listening"
        case .thinking: return "thinking"
        case .talking: return "talking"
        case .celebrating: return "celebrating"
        }
    }

    // MARK: - Subviews

    private func eyeView(size: CGFloat) -> some View {
        ZStack {
            // Eye white — `page` instead of raw white so it flips to warm
            // off-white in light mode and paper-dark in dark mode, matching
            // the rest of the surface system.
            Capsule()
                .fill(NovaPalette.page)
                .overlay(
                    // Thin 1pt ink outline gives the eye the same comic-line
                    // treatment as the body silhouette without stealing weight
                    // from the main 2pt stroke.
                    Capsule()
                        .strokeBorder(NovaPalette.ink, lineWidth: 1)
                )

            // Pupil — `ink` (adaptive) replaces Color.black so dark mode gets
            // the paper-inverse treatment.
            Circle()
                .fill(NovaPalette.ink)
                .frame(width: size * 0.5, height: size * 0.5)
                .offset(x: eyeOffset().x, y: eyeOffset().y)
        }
        .frame(width: size, height: size * 1.2)
    }

    /// Coral cheek — small filled circle placed left/right of the mouth as
    /// the character's 3+1 coral accent. Pure paint; no animation state of
    /// its own, so it inherits bob/scale from the body container.
    private func cheekView(size: CGFloat) -> some View {
        Circle()
            .fill(NovaPalette.coral.opacity(0.75))
            .frame(width: size, height: size)
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
        // Mouth uses `ink` (adaptive) for the stroke so dark mode flips
        // cleanly to paper-light against the sun body. Weight differs by
        // state: celebrating gets a heavier 3pt line for the "big smile"
        // read at a distance, other states use 2pt to sit alongside the
        // body silhouette stroke.
        let strokeWidth: CGFloat = state == .celebrating ? 3 : 2

        return Path { path in
            path.addArc(
                center: CGPoint(x: size / 2, y: size / 2),
                radius: size / 2,
                startAngle: .degrees(0),
                endAngle: .degrees(180),
                clockwise: false
            )
        }
        .stroke(NovaPalette.ink, lineWidth: strokeWidth)
        .frame(width: size, height: size * 0.6)
        .scaleEffect(mouthScale, anchor: .center)
    }

    private func antennaView(size: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Antenna rod — `ink` instead of Color.black so it matches the
            // silhouette stroke weight and flips in dark mode.
            Rectangle()
                .fill(NovaPalette.ink)
                .frame(width: size * 0.4, height: size * 3)

            // Antenna ball — `coral` (was novaYellow). Against the sun body
            // coral gives the ball separation and lands the 3+1 primary on
            // the character's topmost accent.
            Circle()
                .fill(NovaPalette.coral)
                .frame(width: size * 1.5, height: size * 1.5)
                .overlay(
                    // Matching 1pt ink outline keeps the ball feeling like
                    // part of the same comic silhouette family as the body.
                    Circle()
                        .strokeBorder(NovaPalette.ink, lineWidth: 1)
                )
        }
    }

    private func pulseRings(size: CGFloat) -> some View {
        // Coral-only gradient for the listening/thinking rings. Coral reads
        // as "active / energy" in the 3+1 system — this is what the old
        // novaBlue → novaPurple gradient was reaching for; now it lands on
        // the comic palette directly.
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                NovaPalette.coral.opacity(0.6),
                                NovaPalette.coral.opacity(0.2)
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
