import SwiftUI
import NovaCore
import NovaVoice
import UIKit

/// Story card view — a picture-book page rendered inside the
/// `LessonBookReaderShell` workbook chrome.
///
/// The card no longer nests a chalkboard surface; the workbook
/// shell already provides the paper-page silhouette. Story content
/// is laid out as a storybook page: a small bookmark + title header
/// at the top, the hero illustration framed as a paper-mat plate
/// with optional painted-frame asset, narrative copy on a
/// `LessonBookPageSurface` (storybook mood), and a sun-tinted
/// read-aloud sticker. All animation is gated on
/// `accessibilityReduceMotion`.
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
            VStack(alignment: .leading, spacing: Spacing.md) {
                pageHeader

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
                    .frame(minWidth: 880, alignment: .leading)

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
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(cardTitle) story card")
        .accessibilityValue(card.content.narrativeText ?? "")
    }

    /// Storybook page header — a small bookmark ribbon followed by
    /// the lesson title. Replaces the chalkboard surface header that
    /// previously labelled the card; sized to feel like a page-top
    /// title inside the open book rather than a top-of-screen badge.
    private var pageHeader: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            bookmarkOrnament
                .frame(width: 22, height: 36)
                .accessibilityHidden(true)

            Text(cardTitle)
                .font(NovaPalette.headingFont())
                .foregroundStyle(NovaPalette.classroomInk)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xs)
    }

    /// Painted bookmark sticker if the asset is in the bundle,
    /// otherwise a SwiftUI school-red ribbon stand-in.
    @ViewBuilder
    private var bookmarkOrnament: some View {
        if UIImage(named: "lesson_bookmark_45") != nil {
            Image("lesson_bookmark_45")
                .resizable()
                .scaledToFit()
        } else {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(NovaPalette.classroomSchoolRed.opacity(0.88))
                    .overlay(
                        Rectangle()
                            .stroke(NovaPalette.classroomInk.opacity(0.40), lineWidth: 1)
                    )

                // Small notched tail at the bottom of the ribbon.
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: 11, y: 6))
                    path.addLine(to: CGPoint(x: 22, y: 0))
                    path.closeSubpath()
                }
                .fill(NovaPalette.classroomPaper)
                .frame(height: 6)
            }
        }
    }

    private var cardTitle: String {
        if let title = card.content.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           title.isEmpty == false {
            return title
        }

        return "Story"
    }

    /// Hero illustration framed as a paper-mat plate pinned to the
    /// chalkboard. When the painted-frame asset
    /// `lesson_storybook_frame_45_landscape` is available, the inner
    /// image is inset to fit inside the painted border. When it is
    /// not, we drop the asset-specific inset and use a SwiftUI paper
    /// mat with normal `Spacing.sm` padding so the inner illustration
    /// fills the visible frame.
    private var heroPlate: some View {
        Group {
            if UIImage(named: "lesson_storybook_frame_45_landscape") != nil {
                assetFramedHero
            } else {
                swiftUIMattedHero
            }
        }
        .aspectRatio(1448.0 / 1086.0, contentMode: .fit)
        .accessibilityHidden(card.imageURL == nil)
    }

    /// Hero composed against the painted picture-book frame asset.
    /// The 68/52 horizontal/vertical inset is calibrated to land the
    /// inner illustration inside the painted border; do not edit
    /// those numerics without re-checking the frame artwork.
    private var assetFramedHero: some View {
        ZStack {
            heroIllustration
                .padding(.horizontal, 68)
                .padding(.vertical, 52)

            Image("lesson_storybook_frame_45_landscape")
                .resizable()
                .scaledToFit()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// Hero composed against a SwiftUI paper mat for builds where the
    /// painted frame asset has not landed yet. Uses normal padding so
    /// the illustration fills the visible mat instead of inheriting
    /// the asset-frame inset.
    private var swiftUIMattedHero: some View {
        heroIllustration
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Spacing.md + 4, style: .continuous)
                    .fill(NovaPalette.classroomPaper.opacity(0.92))
            )
            .overlay {
                RoundedRectangle(cornerRadius: Spacing.md + 4, style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.55), lineWidth: 2)
            }
            .shadow(color: NovaPalette.classroomInk.opacity(0.18), radius: 6, x: 0, y: 3)
    }

    /// Inner hero illustration — the `CardHeroImage` async-loader plus
    /// a paper-toned fallback. Shared by both the asset-framed and
    /// SwiftUI-matted paths above.
    private var heroIllustration: some View {
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
        .clipShape(RoundedRectangle(cornerRadius: Spacing.md, style: .continuous))
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
