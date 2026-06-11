import SwiftUI
import NovaCore

/// Live preview of a card as it would appear in the Kids app flipbook.
/// Renders the card with NovaPalette (Kids app colors) in a simulated iPad frame.
public struct CardPreviewView: View {
    let card: Card
    @State private var isPlayingVoice = false

    public var body: some View {
        VStack(spacing: 12) {
            // "Simulated" Label
            HStack {
                Text("Simulated")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.horizontal, 16)

            // Preview Frame (iPad 16:9 aspect ratio)
            VStack {
                previewContent()
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fit)
            .background(CompanionPalette.companionBackground)
            .border(CompanionPalette.novaBlue, width: 2)
            .cornerRadius(12)
            .padding(.horizontal, 16)

            Spacer()
        }
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private func previewContent() -> some View {
        ZStack {
            CompanionPalette.companionBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                switch card.type {
                case .story:
                    storyPreview()
                case .concept:
                    conceptPreview()
                case .experiment:
                    experimentPreview()
                case .quiz:
                    quizPreview()
                case .voice:
                    voicePreview()
                case .video:
                    videoPreview()
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func storyPreview() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image placeholder
            if let imageURL = card.imageURL {
                VStack {
                    Image(systemName: "photo")
                        .font(.title.weight(.light))
                        .foregroundStyle(.gray)

                    Text("Image: \(imageURL.lastPathComponent)")
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            // Title
            if let title = card.content.title {
                Text(title)
                    .font(CompanionPalette.headingFont())
                    .fontWeight(.bold)
            }

            // Narrative Text
            if let text = card.content.narrativeText {
                Text(text)
                    .font(CompanionPalette.bodyFont())
                    .foregroundStyle(.primary)
                    .lineLimit(4)
            }

            Spacer()

            // Speaker Icon
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(CompanionPalette.novaOrange)

                Text("Tap to listen")
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func conceptPreview() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image placeholder (full width for concept)
            if let imageURL = card.imageURL {
                VStack {
                    Image(systemName: "photo")
                        .font(.largeTitle.weight(.light))
                        .foregroundStyle(.gray)

                    Text("Image")
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            // Title and Explanation
            VStack(alignment: .leading, spacing: 8) {
                if let title = card.content.title {
                    Text(title)
                        .font(CompanionPalette.headingFont())
                        .fontWeight(.bold)
                }

                if let explanation = card.content.explanation {
                    Text(explanation)
                        .font(CompanionPalette.bodyFont())
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func experimentPreview() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            if let title = card.content.title {
                Text(title)
                    .font(CompanionPalette.headingFont())
                    .fontWeight(.bold)
            }

            // Instructions preview
            if let instructions = card.content.instructions {
                Text(instructions)
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                // Drag items preview
                if let dragItems = card.content.dragItems, !dragItems.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Drag Items")
                            .font(CompanionPalette.smallHeadingFont())
                            .fontWeight(.bold)

                        ForEach(dragItems.prefix(2), id: \.id) { item in
                            HStack {
                                Image(systemName: "hand.tap")
                                    .font(.caption)
                                Text(item.label)
                                    .font(CompanionPalette.captionFont())
                                    .lineLimit(1)
                            }
                            .padding(6)
                            .background(CompanionPalette.novaPurple.opacity(0.2))
                            .cornerRadius(4)
                        }
                    }

                    Spacer()
                }

                // Drop targets preview
                if let dropTargets = card.content.dropTargets, !dropTargets.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Targets")
                            .font(CompanionPalette.smallHeadingFont())
                            .fontWeight(.bold)

                        ForEach(dropTargets.prefix(2), id: \.id) { target in
                            HStack {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                Text(target.label)
                                    .font(CompanionPalette.captionFont())
                                    .lineLimit(1)
                            }
                            .padding(6)
                            .background(CompanionPalette.novaGreen.opacity(0.2))
                            .cornerRadius(4)
                        }
                    }
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func quizPreview() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question
            if let question = card.content.question {
                Text(question)
                    .font(CompanionPalette.headingFont())
                    .fontWeight(.bold)
            }

            // Answer options preview
            if let options = card.content.options, !options.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        Button(action: {}) {
                            HStack {
                                Text(option.text)
                                    .font(CompanionPalette.bodyFont())
                                    .lineLimit(1)

                                Spacer()

                                if index == card.content.correctOptionIndex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(CompanionPalette.novaGreen)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(
                                index == card.content.correctOptionIndex ?
                                CompanionPalette.novaGreen.opacity(0.25) :
                                CompanionPalette.novaBlue.opacity(0.15)
                            )
                            .border(
                                index == card.content.correctOptionIndex ?
                                CompanionPalette.novaGreen :
                                CompanionPalette.novaBlue,
                                width: 1
                            )
                            .cornerRadius(8)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func voicePreview() -> some View {
        VStack(alignment: .center, spacing: 16) {
            // Prompt text
            if let promptText = card.content.promptText {
                Text(promptText)
                    .font(CompanionPalette.bodyFont())
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Mic button
            Button(action: { isPlayingVoice.toggle() }) {
                VStack(spacing: 8) {
                    Image(systemName: isPlayingVoice ? "pause.circle.fill" : "mic.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(CompanionPalette.novaOrange)

                    Text(isPlayingVoice ? "Recording..." : "Tap to speak")
                        .font(CompanionPalette.bodyFont())
                        .foregroundStyle(CompanionPalette.novaOrange)
                }
            }

            Spacer()

            // Voice script indicator
            if card.voiceScript != nil && !card.voiceScript!.isEmpty {
                HStack {
                    Image(systemName: "speaker.wave.2")
                        .font(.subheadline)
                        .foregroundStyle(CompanionPalette.novaBlue)

                    Text("Narration recorded")
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func videoPreview() -> some View {
        VStack(alignment: .center, spacing: 16) {
            Spacer()

            // Video player placeholder
            VStack(spacing: 12) {
                Image(systemName: "film.fill")
                    .font(.largeTitle.weight(.light))
                    .foregroundStyle(CompanionPalette.novaBlue)

                if let videoURL = card.content.videoURL {
                    Text(videoURL.lastPathComponent)
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)
                } else {
                    Text("No video selected")
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)
                }
            }

            // Play button
            Button(action: {}) {
                Image(systemName: "play.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(CompanionPalette.novaOrange)
            }

            Spacer()

            // Pause points info
            if let pausePoints = card.content.pausePoints, !pausePoints.isEmpty {
                HStack {
                    Image(systemName: "timer")
                        .font(.subheadline)
                        .foregroundStyle(CompanionPalette.novaBlue)

                    Text("\(pausePoints.count) pause point\(pausePoints.count == 1 ? "" : "s")")
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    VStack {
        CardPreviewView(card: Card.mockCard())
        Spacer()
    }
}
