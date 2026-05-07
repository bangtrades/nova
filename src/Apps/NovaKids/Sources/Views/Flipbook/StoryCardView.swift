import SwiftUI
import NovaCore
import NovaVoice
import UIKit

/// Story card view — a picture-book page rendered inside the
/// classroom chalkboard surface.
///
/// The hero illustration sits on a paper "mat" with two corner-tape
/// stickers, narrative copy is rendered on a `LessonBookPageSurface`
/// (storybook mood), and the read-aloud button is a sun-tinted
/// classroom sticker that matches the rest of the classroom Home
/// shell. All animation is gated on `accessibilityReduceMotion`.
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
        ScrollView(.vertical, showsIndicators: false) {
            ChalkboardLessonCardSurface(cardKind: .story, title: cardTitle) {
                ViewThatFits(in: .horizontal) {
                    // Wide layout (iPad landscape): illustration on the
                    // leading edge, narrative + read button alongside.
                    // The minWidth gate keeps `ViewThatFits` from picking
                    // this branch on iPad portrait where the text column
                    // would squeeze.
                    HStack(alignment: .top, spacing: Spacing.lg) {
                        heroPlate
                            .frame(width: 320)
                            .frame(maxHeight: 260)

                        VStack(alignment: .leading, spacing: Spacing.md) {
                            storyPage

                            HStack(spacing: Spacing.sm) {
                                Spacer()
                                speakerSticker
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minWidth: 940, alignment: .leading)

                    // Stacked layout (iPad portrait, iPhone, narrow
                    // splits): illustration on top, narrative below,
                    // read button trailing-aligned at the bottom.
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        heroPlate
                            .frame(maxHeight: 260)

                        storyPage

                        HStack(spacing: Spacing.sm) {
                            Spacer()
                            speakerSticker
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
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

    /// Hero illustration framed as a paper-mat plate pinned to the
    /// chalkboard. Falls back to a paper placeholder with a book glyph
    /// when no `imageURL` is available.
    private var heroPlate: some View {
        ZStack {
            CardHeroImage(url: card.imageURL) {
                ZStack {
                    LinearGradient(
                        colors: [
                            NovaPalette.classroomSky.opacity(0.32),
                            NovaPalette.classroomPaper,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: Spacing.sm) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(NovaPalette.classroomInk)
                            .accessibilityHidden(true)

                        Text("Storybook")
                            .font(NovaPalette.captionFont().weight(.bold))
                            .foregroundStyle(NovaPalette.classroomInk.opacity(0.75))
                    }
                }
            }
            .padding(.horizontal, 68)
            .padding(.vertical, 52)

            if UIImage(named: "lesson_storybook_frame_45_landscape") != nil {
                Image("lesson_storybook_frame_45_landscape")
                    .resizable()
                    .scaledToFit()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            } else {
                fallbackHeroMat
            }
        }
        .aspectRatio(1448.0 / 1086.0, contentMode: .fit)
        .accessibilityHidden(card.imageURL == nil)
    }

    private var fallbackHeroMat: some View {
        RoundedRectangle(cornerRadius: Spacing.md + 4, style: .continuous)
            .fill(NovaPalette.classroomPaper.opacity(0.92))
            .overlay {
                RoundedRectangle(cornerRadius: Spacing.md + 4, style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.55), lineWidth: 2)
            }
            .shadow(color: NovaPalette.classroomInk.opacity(0.18), radius: 6, x: 0, y: 3)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Narrative text rendered on a storybook paper page so the copy
    /// reads as book text rather than dashboard text.
    @ViewBuilder
    private var storyPage: some View {
        if let narrative = card.content.narrativeText {
            LessonBookPageSurface(mood: .storybook) {
                Text(narrative)
                    .font(NovaPalette.largeBodyFont())
                    .foregroundStyle(NovaPalette.classroomInk)
                    .lineSpacing(4)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    /// Read-aloud control rendered as a sun-tinted classroom sticker —
    /// matches the sticker family used by the classroom-home tap
    /// stickers and trophy count badge. Pulses on the sun ring while
    /// speaking, fully gated on Reduce Motion.
    private var speakerSticker: some View {
        Button(action: speakStory) {
            ZStack {
                if isSpeaking && reduceMotion == false {
                    Circle()
                        .fill(NovaPalette.classroomSun.opacity(0.45))
                        .scaleEffect(pulseAnimation ? 1.25 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true),
                            value: pulseAnimation
                        )
                }

                HStack(spacing: 6) {
                    Image(systemName: isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.1.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(NovaPalette.classroomInk)
                        .accessibilityHidden(true)

                    Text("Read")
                        .font(NovaPalette.captionFont().weight(.black))
                        .foregroundStyle(NovaPalette.classroomInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(readAloudBackground)
            }
            .frame(minWidth: 88, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(isSpeaking)
        .accessibilityLabel("Read aloud")
        .accessibilityValue(isSpeaking ? "Currently speaking" : "Not speaking")
        .onAppear {
            pulseAnimation = true
        }
    }

    @ViewBuilder
    private var readAloudBackground: some View {
        if UIImage(named: "lesson_read_aloud_45") != nil {
            Image("lesson_read_aloud_45")
                .resizable()
                .scaledToFill()
                .frame(width: 116, height: 50)
                .clipped()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            Capsule(style: .continuous)
                .fill(NovaPalette.classroomSun)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(NovaPalette.classroomInk, lineWidth: 1.5)
                }
                .shadow(color: NovaPalette.classroomInk.opacity(0.18), radius: 2, x: 0, y: 1)
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
