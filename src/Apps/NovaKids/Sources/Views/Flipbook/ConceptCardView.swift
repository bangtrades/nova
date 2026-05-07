import SwiftUI
import NovaCore
import NovaVoice
import UIKit

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
        ScrollView(.vertical, showsIndicators: false) {
            ChalkboardLessonCardSurface(cardKind: .concept, title: surfaceTitle) {
                ViewThatFits(in: .horizontal) {
                    // Wide workbook layout (iPad landscape): diagram /
                    // illustration on the leading edge, "big idea" page
                    // alongside, read button trailing at the bottom of
                    // the page column. The minWidth gate keeps narrow
                    // sizes off this branch.
                    HStack(alignment: .top, spacing: Spacing.lg) {
                        heroPanel
                            .frame(width: 320)
                            .frame(maxHeight: 260)

                        VStack(alignment: .leading, spacing: Spacing.md) {
                            explanationNote

                            HStack(spacing: Spacing.sm) {
                                Spacer()
                                speakerButton
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minWidth: 940, alignment: .leading)

                    // Stacked workbook layout (iPad portrait, narrow
                    // splits): diagram on top, big-idea page in the
                    // middle, read button trailing-aligned at the
                    // bottom.
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        heroPanel
                            .frame(maxHeight: 240)

                        explanationNote

                        HStack(spacing: Spacing.sm) {
                            Spacer()
                            speakerButton
                        }
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

    /// "Big idea" workbook page: the explanation rendered on a paper
    /// note pinned inside the chalkboard surface, with a small
    /// sun-circle + ruled cap that nods to a worksheet header.
    @ViewBuilder
    private var explanationNote: some View {
        if let explanation = card.content.explanation {
            LessonBookPageSurface(mood: .workbook) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(NovaPalette.classroomSun)
                            .overlay {
                                Circle().stroke(NovaPalette.classroomInk.opacity(0.55), lineWidth: 1)
                            }
                            .frame(width: 12, height: 12)
                            .accessibilityHidden(true)

                        Capsule(style: .continuous)
                            .fill(NovaPalette.classroomInk.opacity(0.20))
                            .frame(width: 92, height: 4)
                            .accessibilityHidden(true)
                    }

                    Text(explanation)
                        .font(NovaPalette.largeBodyFont())
                        .foregroundStyle(NovaPalette.classroomInk)
                        .lineSpacing(4)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
        }
    }

    /// Read-aloud control rendered as a sun-tinted classroom sticker
    /// matching the rest of the classroom-shell sticker family. Pulse
    /// gated on Reduce Motion.
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
                if isSpeaking && !reduceMotion {
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
