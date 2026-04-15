import SwiftUI
import NovaCore

/// Editor for a single card within a lesson.
public struct CardEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State var card: Card
    let lessonId: UUID
    let onSave: (Card) -> Void

    @State private var selectedCardType: Card.CardType
    @State private var showingTypeMenu = false

    init(card: Card = Card.mockCard(), lessonId: UUID, onSave: @escaping (Card) -> Void) {
        _card = State(initialValue: card)
        _selectedCardType = State(initialValue: card.type)
        self.lessonId = lessonId
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Card Type Selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Card Type")
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)

                            HStack {
                                Menu {
                                    ForEach(Card.CardType.allCases, id: \.self) { type in
                                        Button(action: { selectedCardType = type }) {
                                            HStack {
                                                Text(type.displayName)
                                                if selectedCardType == type {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedCardType.displayName)
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
                        }
                        .padding(.horizontal, 16)

                        // Content Fields (based on type)
                        cardTypeContentView()

                        // Preview Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)

                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "eye.fill")
                                        .font(.headline)
                                        .foregroundStyle(CompanionPalette.novaBlue)

                                    Text("Preview coming in Sprint 4")
                                        .font(CompanionPalette.secondaryBodyFont())
                                        .foregroundStyle(.secondary)

                                    Spacer()
                                }
                                .padding(12)
                            }
                            .frame(maxWidth: .infinity)
                            .background(CompanionPalette.companionCard)
                            .border(CompanionPalette.companionBorder, width: 1)
                            .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)

                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.vertical, 16)
                }

                // Save/Delete Footer
                VStack(spacing: 0) {
                    Divider()

                    HStack(spacing: 12) {
                        Button(role: .destructive, action: { dismiss() }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.3)))
                        }

                        Button(action: { onSave(card); dismiss() }) {
                            Text("Save Card")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(CompanionPalette.novaBlue)
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Edit Card")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func cardTypeContentView() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Content")
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)
                .padding(.horizontal, 16)

            switch selectedCardType {
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
        .padding(.horizontal, 16)
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
        .padding(.horizontal, 16)
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
        .padding(.horizontal, 16)
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
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func voiceFields() -> some View {
        VStack(spacing: 12) {
            textField(label: "Voice Prompt", text: Binding(
                get: { card.content.promptText ?? "" },
                set: { card.content.promptText = $0 }
            ), isMultiline: true)

            textField(label: "Voice Script (narrator)", text: Binding(
                get: { card.voiceScript ?? "" },
                set: { card.voiceScript = $0 }
            ), isMultiline: true)
        }
        .padding(.horizontal, 16)
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
        .padding(.horizontal, 16)
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

extension Card.CardType {
    var displayName: String {
        switch self {
        case .story:
            return "Story"
        case .concept:
            return "Concept"
        case .experiment:
            return "Experiment"
        case .quiz:
            return "Quiz"
        case .voice:
            return "Voice"
        case .video:
            return "Video"
        }
    }
}

extension Card {
    static func mockCard() -> Card {
        Card(
            lessonId: UUID(),
            type: .concept,
            sortOrder: 1,
            content: Card.CardContent(
                title: "Untitled Card",
                explanation: "Enter your explanation here..."
            )
        )
    }
}

#Preview {
    CardEditorView(
        card: Card.mockCard(),
        lessonId: UUID(),
        onSave: { _ in }
    )
}
