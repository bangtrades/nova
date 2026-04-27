import SwiftUI
import NovaCore
import NovaVoice

/// Story card view displaying narrative content with voice narration.
///
/// Shows a large illustration with story text below and speaker button
/// for TTS voice narration. Includes gentle animations on appear.
public struct StoryCardView: View {
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
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    NovaPalette.novaBlue.opacity(0.25),
                    NovaPalette.novaOrange.opacity(0.15),
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // S13: Large illustration area (80%) — DALL-E hero image
                // when card.imageURL is set, gradient + book-icon
                // placeholder when not (lesson seeded before asset
                // pipeline ran, or OPENAI_API_KEY wasn't configured).
                CardHeroImage(url: card.imageURL) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        NovaPalette.novaBlue.opacity(0.4),
                                        NovaPalette.novaPurple.opacity(0.3),
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        VStack(spacing: 16) {
                            Image(systemName: "book.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                                .accessibilityHidden(true)

                            Text("Story Card")
                                .font(NovaPalette.headingFont())
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(24)
                .scaleEffect(0.95)
                .opacity(0.9)
                .onAppear {
                    withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.6)) {
                        // Animate on appear
                    }
                }

                // Story text area (20%) with gradient overlay
                VStack(alignment: .leading, spacing: 16) {
                    if let narrative = card.content.narrativeText {
                        Text(narrative)
                            .font(NovaPalette.largeBodyFont())
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack {
                        Spacer()

                        // Speaker button for TTS
                        Button(action: {
                            if let script = card.voiceScript ?? card.content.narrativeText {
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
                                    .font(.title2)
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
                    LinearGradient(
                        gradient: Gradient(colors: [
                            NovaPalette.novaCardBackground,
                            NovaPalette.novaBackground,
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Story Card")
        .accessibilityValue(card.content.narrativeText ?? "")
    }
}

#Preview {
    let card = Card(
        id: UUID(),
        lessonId: UUID(),
        type: .story,
        sortOrder: 0,
        content: Card.CardContent(
            title: "Story",
            narrativeText: "Once upon a time, a curious child asked, 'How do computers learn?'"
        ),
        voiceScript: "Once upon a time, a curious child asked, How do computers learn?"
    )

    let speechSynthesizer = SpeechSynthesizer()
    let voiceManager = VoiceManager(speechSynthesizer: speechSynthesizer)

    StoryCardView(card: card)
        .environmentObject(voiceManager)
}
