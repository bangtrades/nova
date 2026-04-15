import SwiftUI
import NovaCore

/// Form for editing card content, extracted from CardEditorView.
/// Displays type-specific fields with character counts and voice preview.
public struct CardFormView: View {
    @Binding var card: Card
    @State private var voiceScript: String
    @State private var isPlayingVoice = false

    init(card: Binding<Card>) {
        _card = card
        _voiceScript = State(initialValue: card.wrappedValue.voiceScript ?? "")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card Type Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Card Type")
                    .font(CompanionPalette.bodyFont())
                    .fontWeight(.semibold)

                Menu {
                    ForEach(Card.CardType.allCases, id: \.self) { type in
                        Button(action: { card.type = type }) {
                            HStack {
                                Text(type.displayName)
                                if card.type == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(card.type.displayName)
                            .font(CompanionPalette.bodyFont())
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(CompanionPalette.companionCard)
                    .border(CompanionPalette.companionBorder, width: 1)
                    .cornerRadius(8)
                    .foregroundStyle(.primary)
                }
            }

            // Content Fields (based on type)
            contentFieldsForType()

            Spacer()
        }
    }

    @ViewBuilder
    private func contentFieldsForType() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Content")
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)

            switch card.type {
            case .story:
                storyFields()
            case .concept:
                conceptFields()
            case .experiment:
                experimentFields()
            case .quiz:
                quizFields()
            case .voice:
                voiceFields()
            case .video:
                videoFields()
            }
        }
    }

    @ViewBuilder
    private func storyFields() -> some View {
        VStack(spacing: 12) {
            textField(label: "Story Title", text: Binding(
                get: { card.content.title ?? "" },
                set: { card.content.title = $0 }
            ))

            textField(label: "Narrative Text", text: Binding(
                get: { card.content.narrativeText ?? "" },
                set: { card.content.narrativeText = $0 }
            ), isMultiline: true)

            textField(label: "Image URL", text: Binding(
                get: { card.imageURL?.absoluteString ?? "" },
                set: { card.imageURL = URL(string: $0) }
            ))
        }
    }

    @ViewBuilder
    private func conceptFields() -> some View {
        VStack(spacing: 12) {
            textField(label: "Concept Title", text: Binding(
                get: { card.content.title ?? "" },
                set: { card.content.title = $0 }
            ))

            textField(label: "Explanation", text: Binding(
                get: { card.content.explanation ?? "" },
                set: { card.content.explanation = $0 }
            ), isMultiline: true)

            textField(label: "Image URL", text: Binding(
                get: { card.imageURL?.absoluteString ?? "" },
                set: { card.imageURL = URL(string: $0) }
            ))
        }
    }

    @ViewBuilder
    private func experimentFields() -> some View {
        VStack(spacing: 12) {
            textField(label: "Experiment Title", text: Binding(
                get: { card.content.title ?? "" },
                set: { card.content.title = $0 }
            ))

            textField(label: "Instructions", text: Binding(
                get: { card.content.instructions ?? "" },
                set: { card.content.instructions = $0 }
            ), isMultiline: true)

            HStack {
                Image(systemName: "info.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CompanionPalette.novaBlue)

                Text("Drag items and drop targets configured in advanced settings")
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(CompanionPalette.novaBlue.opacity(0.1))
            .cornerRadius(6)
        }
    }

    @ViewBuilder
    private func quizFields() -> some View {
        VStack(spacing: 12) {
            textField(label: "Question", text: Binding(
                get: { card.content.question ?? "" },
                set: { card.content.question = $0 }
            ), isMultiline: true)

            HStack {
                Image(systemName: "info.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CompanionPalette.novaBlue)

                Text("Quiz options configured in advanced settings")
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(CompanionPalette.novaBlue.opacity(0.1))
            .cornerRadius(6)
        }
    }

    @ViewBuilder
    private func voiceFields() -> some View {
        VStack(spacing: 12) {
            textField(label: "Voice Prompt", text: Binding(
                get: { card.content.promptText ?? "" },
                set: { card.content.promptText = $0 }
            ), isMultiline: true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Voice Script (narrator)")
                        .font(CompanionPalette.captionFont())
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(voiceScript.count)/300")
                        .font(CompanionPalette.smallCaptionFont())
                        .foregroundStyle(voiceScript.count > 300 ? .red : .secondary)
                }

                TextEditor(text: $voiceScript)
                    .frame(minHeight: 80)
                    .font(CompanionPalette.bodyFont())
                    .padding(8)
                    .background(CompanionPalette.companionCard)
                    .border(CompanionPalette.companionBorder, width: 1)
                    .cornerRadius(6)
                    .onChange(of: voiceScript) { _, newValue in
                        card.voiceScript = newValue
                    }
            }

            Button(action: { isPlayingVoice.toggle() }) {
                HStack(spacing: 8) {
                    Image(systemName: isPlayingVoice ? "pause.circle.fill" : "play.circle.fill")
                    Text(isPlayingVoice ? "Stop Preview" : "Preview Voice")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(CompanionPalette.novaBlue)
                .foregroundStyle(.white)
                .cornerRadius(8)
            }
        }
    }

    @ViewBuilder
    private func videoFields() -> some View {
        VStack(spacing: 12) {
            textField(label: "Video URL", text: Binding(
                get: { card.content.videoURL?.absoluteString ?? "" },
                set: { card.content.videoURL = URL(string: $0) }
            ))

            HStack {
                Image(systemName: "info.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CompanionPalette.novaBlue)

                Text("Pause points configured in advanced settings")
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(CompanionPalette.novaBlue.opacity(0.1))
            .cornerRadius(6)
        }
    }

    private func textField(label: String, text: Binding<String>, isMultiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(CompanionPalette.captionFont())
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if isMultiline {
                TextEditor(text: text)
                    .frame(minHeight: 80)
                    .font(CompanionPalette.bodyFont())
                    .padding(8)
                    .background(CompanionPalette.companionCard)
                    .border(CompanionPalette.companionBorder, width: 1)
                    .cornerRadius(6)
            } else {
                TextField(label, text: text)
                    .font(CompanionPalette.bodyFont())
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(CompanionPalette.companionCard)
                    .border(CompanionPalette.companionBorder, width: 1)
                    .cornerRadius(6)
            }
        }
    }
}

#Preview {
    VStack {
        CardFormView(card: .constant(Card.mockCard()))
        Spacer()
    }
    .padding()
}
