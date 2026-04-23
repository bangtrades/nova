import SwiftUI
import NovaCore
import NovaVoice

/// Voice interaction card with speech recognition and AI responses.
///
/// Shows a prompt, microphone button for recording, and plays back AI responses
/// with animated waveform feedback.
public struct VoiceCardView: View {
    /// The card to display.
    let card: Card

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @EnvironmentObject var voiceManager: VoiceManager

    @State private var isRecording = false
    @State private var isProcessing = false
    @State private var isResponding = false
    @State private var responseText: String = ""
    @State private var waveformHeight: [Double] = [0.2, 0.3, 0.5, 0.4, 0.3]
    @State private var animationTimer: Timer? = nil
    @State private var sparkleScale: Double = 1.0
    @State private var sparkleOpacity: Double = 0
    @State private var processingTask: Task<Void, Never>?
    @State private var sparkleTask: Task<Void, Never>?

    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    public init(card: Card) {
        self.card = card
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    NovaPalette.novaPurple.opacity(0.1),
                    NovaPalette.novaBlue.opacity(0.1),
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    if let title = card.content.title {
                        Text(title)
                            .font(NovaPalette.headingFont())
                            .foregroundStyle(.primary)
                    }

                    if let prompt = card.content.promptText {
                        Text(prompt)
                            .font(NovaPalette.largeBodyFont())
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)

                Spacer()

                // Microphone button
                if !isResponding {
                    VStack(spacing: 24) {
                        // Waveform visualization
                        if isRecording && !reduceMotion {
                            HStack(alignment: .center, spacing: 4) {
                                ForEach(0..<waveformHeight.count, id: \.self) { index in
                                    Capsule()
                                        .fill(NovaPalette.novaOrange)
                                        .frame(width: 4, height: 40 * waveformHeight[index])
                                        .frame(minWidth: 44, minHeight: 44)
                                        .contentShape(Capsule())
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(height: 60)
                            .padding(.horizontal, 40)
                            .accessibilityHidden(true)
                        }

                        // Main microphone button
                        ZStack {
                            // Background circle
                            Circle()
                                .fill(
                                    isRecording
                                        ? NovaPalette.novaOrange
                                        : NovaPalette.novaPurple
                                )
                                .frame(width: 120, height: 120)

                            // Pulsing ring when recording
                            if isRecording && !reduceMotion {
                                Circle()
                                    .strokeBorder(
                                        NovaPalette.novaOrange,
                                        lineWidth: 3
                                    )
                                    .frame(width: 140, height: 140)
                                    .scaleEffect(1.5)
                                    .opacity(0.3)
                                    .animation(
                                        Animation.easeInOut(duration: 1)
                                            .repeatForever(autoreverses: true),
                                        value: isRecording
                                    )
                            }

                            // Microphone icon
                            Image(systemName: isRecording ? "mic.fill" : "mic")
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                                .accessibilityHidden(true)
                        }
                        .onTapGesture {
                            toggleRecording()
                        }

                        // Status text
                        Text(
                            isRecording ? "Recording..." :
                            isProcessing ? "Processing..." :
                            "Tap to talk"
                        )
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(.secondary)
                    }
                }

                // Response display
                if isResponding {
                    VStack(spacing: 16) {
                        // Dashy avatar with sparkle
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            NovaPalette.novaPurple,
                                            NovaPalette.novaBlue,
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)

                            VStack(spacing: 8) {
                                // Eyes
                                HStack(spacing: 16) {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 10, height: 10)
                                        .accessibilityHidden(true)

                                    Circle()
                                        .fill(.white)
                                        .frame(width: 10, height: 10)
                                        .accessibilityHidden(true)
                                }
                                .accessibilityHidden(true)

                                // Smile
                                Arc(start: 0, end: .pi, radius: 8)
                                    .stroke(Color.white, lineWidth: 2)
                                    .accessibilityHidden(true)
                            }
                            .frame(width: 40)

                            // Sparkle effect
                            Image(systemName: "star.fill")
                                .font(.headline)
                                .foregroundStyle(NovaPalette.novaYellow)
                                .offset(x: 35, y: -35)
                                .scaleEffect(sparkleScale)
                                .opacity(sparkleOpacity)
                                .accessibilityHidden(true)
                        }
                        .padding(.bottom, 16)

                        // Response text
                        Text(responseText)
                            .font(NovaPalette.largeBodyFont())
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        // Next button
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Text("Next →")
                                    .fontWeight(.semibold)
                                Image(systemName: "chevron.right")
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(NovaPalette.novaGreen)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 20)
        }
        .onAppear {
            setupAnimations()
        }
        .onDisappear {
            cleanup()
        }
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateWaveform()
        }

        Task {
            do {
                let stream = try await speechRecognizer.startListening()
                for await _ in stream {
                    // Consume stream to keep recognition active
                }
            } catch {
                isRecording = false
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        animationTimer?.invalidate()
        animationTimer = nil

        Task {
            speechRecognizer.stopListening()

            let currentTranscript = speechRecognizer.transcript
            guard !currentTranscript.isEmpty else { return }

            // Simulate processing
            isProcessing = true
            processingTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                isProcessing = false
                showResponse(for: currentTranscript)
            }
        }
    }

    private func updateWaveform() {
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 0.1)) {
                for i in 0..<waveformHeight.count {
                    waveformHeight[i] = Double.random(in: 0.2...1.0)
                }
            }
        }
    }

    private func showResponse(for transcript: String) {
        isResponding = true
        responseText = "That's a great answer! You said: \"\(transcript.prefix(50))...\""

        // Animate sparkle
        withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.6)) {
            sparkleScale = 1.5
            sparkleOpacity = 1.0
        }

        if !reduceMotion {
            sparkleTask = Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.4)) {
                    sparkleOpacity = 0
                }
            }
        } else {
            sparkleOpacity = 0
        }

        // S11-15: voice record commit — commit beat (medium) matches the
        // ladder for "user made a decisive input". Not a celebration; the
        // celebration comes from downstream evaluation.
        NovaHaptics.commit()
    }

    private func setupAnimations() {
        // Pre-load any animations if needed
    }

    private func cleanup() {
        animationTimer?.invalidate()
        animationTimer = nil
        processingTask?.cancel()
        sparkleTask?.cancel()
        speechRecognizer.stopListening()
    }
}

/// Arc shape for Dashy's smile.
private struct Arc: Shape {
    var start: Double
    var end: Double
    var radius: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let startPoint = CGPoint(
            x: center.x + radius * cos(start),
            y: center.y + radius * sin(start)
        )

        path.move(to: startPoint)
        path.addArc(center: center, radius: radius, startAngle: .radians(start), endAngle: .radians(end), clockwise: false)

        return path
    }
}

#Preview {
    let card = Card(
        id: UUID(),
        lessonId: UUID(),
        type: .voice,
        sortOrder: 0,
        content: Card.CardContent(
            title: "Voice Input",
            promptText: "What do you think about learning with AI?",
            expectedResponses: ["learn", "fun", "interesting"]
        )
    )

    return VoiceCardView(card: card)
        .environmentObject(VoiceManager(
            speechSynthesizer: SpeechSynthesizer(),
            remoteTTSClient: nil
        ))
}
