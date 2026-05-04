import SwiftUI
import NovaCore
import NovaVoice

/// Concept card view displaying a key learning concept.
public struct ConceptCardView: View {
    /// The card to display.
    let card: Card

    /// Voice manager for TTS narration.
    @EnvironmentObject var voiceManager: VoiceManager

    @State private var isSpeaking = false
    @State private var pulseAnimation = false

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    public init(card: Card) {
        self.card = card
    }

    public var body: some View {
        ScrollView {
            ChalkboardLessonCardSurface(cardKind: .concept, title: surfaceTitle) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    heroPanel

                    HStack(alignment: .bottom, spacing: Spacing.lg) {
                        explanationNote

                        Spacer(minLength: Spacing.sm)

                        speakerButton
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Concept Card")
        .accessibilityValue(card.content.explanation ?? "")
    }

    private var surfaceTitle: String {
        if let title = card.content.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title
        }
        return "Concept"
    }

    private var heroPanel: some View {
        CardHeroImage(url: card.imageURL) {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        NovaPalette.classroomChalkboard,
                        NovaPalette.classroomSky.opacity(0.34),
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: Spacing.sm) {
                    Image(systemName: "lightbulb.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(NovaPalette.classroomSun)
                        .accessibilityHidden(true)

                    Text("Concept Card")
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(NovaPalette.classroomChalkDust)
                }
                .padding(Spacing.lg)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 260)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Spacing.md, style: .continuous)
                .stroke(NovaPalette.classroomChalkDust.opacity(0.42), lineWidth: 2)
        }
        .accessibilityHidden(card.imageURL == nil)
    }

    @ViewBuilder
    private var explanationNote: some View {
        if let explanation = card.content.explanation {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(NovaPalette.classroomSun)
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)

                    Capsule(style: .continuous)
                        .fill(NovaPalette.classroomChalkDust.opacity(0.42))
                        .frame(width: 92, height: 5)
                        .accessibilityHidden(true)
                }

                Text(explanation)
                    .font(NovaPalette.largeBodyFont())
                    .foregroundStyle(NovaPalette.classroomChalkDust)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Spacing.sm, style: .continuous)
                    .fill(NovaPalette.classroomChalkboard.opacity(0.72))
            )
            .overlay {
                RoundedRectangle(cornerRadius: Spacing.sm, style: .continuous)
                    .stroke(NovaPalette.classroomChalkDust.opacity(0.30), lineWidth: 1.5)
            }
        }
    }

    private var speakerButton: some View {
        Button(action: {
            if let script = card.voiceScript ?? card.content.explanation {
                Task {
                    isSpeaking = true
                    // S13-09: defaults to OpenAI TTS via backend proxy.
                    try? await voiceManager.speak(text: script)
                    isSpeaking = false
                }
            }
        }) {
            ZStack {
                // Pulsing background when speaking
                if isSpeaking && !reduceMotion {
                    Circle()
                        .fill(NovaPalette.classroomSun.opacity(0.34))
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                }

                // Button content
                Image(systemName: isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.1.fill")
                    .font(.title3)
                    .foregroundStyle(NovaPalette.classroomInk)
                    .accessibilityHidden(true)
            }
            .frame(width: 48, height: 48)
            .background(NovaPalette.classroomSun)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(NovaPalette.classroomInk.opacity(0.55), lineWidth: 2)
            }
        }
        .disabled(isSpeaking)
        .accessibilityLabel("Read aloud")
        .accessibilityValue(isSpeaking ? "Currently speaking" : "Not speaking")
        .onAppear {
            pulseAnimation = true
        }
    }
}

#Preview {
    let card = Card(
        id: UUID(),
        lessonId: UUID(),
        type: .concept,
        sortOrder: 1,
        content: Card.CardContent(
            title: "Concept",
            explanation: "AI learns by looking at many examples and finding patterns."
        ),
        voiceScript: "AI learns by looking at many examples and finding patterns."
    )

    let speechSynthesizer = SpeechSynthesizer()
    let voiceManager = VoiceManager(speechSynthesizer: speechSynthesizer)

    ConceptCardView(card: card)
        .environmentObject(voiceManager)
}
