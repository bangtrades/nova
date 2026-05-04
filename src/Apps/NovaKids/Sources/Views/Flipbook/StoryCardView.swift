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
        ChalkboardLessonCardSurface(cardKind: .story, title: cardTitle) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                heroImage

                storyText

                HStack {
                    Spacer()

                    speakerButton
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(cardTitle) story card")
        .accessibilityValue(card.content.narrativeText ?? "")
    }

    private var cardTitle: String {
        if let title = card.content.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           title.isEmpty == false {
            return title
        }

        return "Story"
    }

    private var heroImage: some View {
        CardHeroImage(url: card.imageURL) {
            ZStack {
                RoundedRectangle(cornerRadius: Spacing.md, style: .continuous)
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

                VStack(spacing: Spacing.md) {
                    Image(systemName: "book.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)

                    Text("Story Card")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(minHeight: 220, idealHeight: 300, maxHeight: 360)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.md, style: .continuous))
        .scaleEffect(0.98)
        .opacity(0.96)
        .onAppear {
            withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.6)) { }
        }
    }

    @ViewBuilder
    private var storyText: some View {
        if let narrative = card.content.narrativeText {
            Text(narrative)
                .font(.body)
                .foregroundStyle(NovaPalette.classroomInk)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var speakerButton: some View {
        Button(action: speakStory) {
            ZStack {
                if isSpeaking && reduceMotion == false {
                    Circle()
                        .fill(NovaPalette.novaOrange.opacity(0.3))
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                }

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

    private func speakStory() {
        if let script = card.voiceScript ?? card.content.narrativeText {
            Task {
                isSpeaking = true
                try? await voiceManager.speak(text: script)
                isSpeaking = false
            }
        }
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
