import SwiftUI
import NovaCore
import NovaVoice

/// Concept card view displaying a key learning concept.
///
/// Full-screen image background with a concept sentence at the bottom
/// in a frosted glass box. Emphasizes key concept words.
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
        ZStack(alignment: .bottom) {
            // S13: full-bleed hero image when card.imageURL is set,
            // gradient + lightbulb-icon placeholder when not. Replaces
            // the previous gradient-only background so concept cards
            // get their comic-book panel illustration.
            CardHeroImage(url: card.imageURL) {
                ZStack {
                    LinearGradient(
                        gradient: Gradient(colors: [
                            NovaPalette.novaGreen.opacity(0.4),
                            NovaPalette.novaBlue.opacity(0.3),
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: 20) {
                        Image(systemName: "lightbulb.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)

                        Text("Concept Card")
                            .font(NovaPalette.headingFont())
                            .foregroundStyle(.white)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                }
            }
            .ignoresSafeArea()

            // Concept text in frosted glass box at bottom
            VStack(spacing: 12) {
                if let explanation = card.content.explanation {
                    VStack(alignment: .leading, spacing: 8) {
                        // Render concept text with emphasis on key words
                        Text(explanation)
                            .font(NovaPalette.largeBodyFont())
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack {
                    Spacer()

                    Button(action: {
                        if let script = card.voiceScript ?? card.content.explanation {
                            Task {
                                isSpeaking = true
                                try? await voiceManager.speak(text: script, preferRemote: false)
                                isSpeaking = false
                            }
                        }
                    }) {
                        ZStack {
                            // Pulsing background when speaking
                            if isSpeaking && !reduceMotion {
                                Circle()
                                    .fill(NovaPalette.novaOrange.opacity(0.3))
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
                                .foregroundStyle(.white)
                                .accessibilityHidden(true)
                        }
                        .frame(width: 48, height: 48)
                        .background(NovaPalette.novaOrange)
                        .clipShape(Circle())
                    }
                    .disabled(isSpeaking)
                    .accessibilityLabel("Read aloud")
                    .accessibilityValue(isSpeaking ? "Currently speaking" : "Not speaking")
                    .onAppear {
                        pulseAnimation = true
                    }
                }
            }
            .padding(20)
            .background(
                ZStack {
                    // Frosted glass effect
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.15))
                        .backdrop()

                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                }
            )
            .margin(EdgeInsets(top: 0, leading: 20, bottom: 24, trailing: 20))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Concept Card")
        .accessibilityValue(card.content.explanation ?? "")
    }
}

/// Helper for frosted glass effect.
struct BackdropModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func backdrop() -> some View {
        modifier(BackdropModifier())
    }

    func margin(_ edges: EdgeInsets) -> some View {
        padding(edges)
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
