import SwiftUI
import NovaCore

/// Publish confirmation modal with pre-publish checklist and asset generation.
/// Shows lesson summary, validation checklist, and options to publish or generate assets first.
public struct PublishFlowView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: PublishFlowViewModel
    @State private var childName: String = "Your child"

    init(lesson: Lesson) {
        _viewModel = StateObject(wrappedValue: PublishFlowViewModel(lesson: lesson))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Publish Lesson")
                                .font(CompanionPalette.titleFont())

                            Text("Ready to share with \(childName)?")
                                .font(CompanionPalette.secondaryBodyFont())
                                .foregroundStyle(.secondary)
                        }

                        // Lesson Summary
                        lessonSummaryCard()

                        // Pre-Publish Checklist
                        checklistSection()

                        // Status Message
                        statusMessage()

                        // Action Buttons (based on state)
                        actionButtons()

                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                    }
                }
            }
            .onAppear {
                viewModel.runChecklist()
            }
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private func lessonSummaryCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Lesson Summary")
                    .font(CompanionPalette.bodyFont())
                    .fontWeight(.semibold)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Title")
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(viewModel.lesson.title)
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)
                }

                Divider()

                HStack {
                    Text("Cards")
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(viewModel.lesson.cards?.count ?? 0)")
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)
                }

                Divider()

                // Card types breakdown
                if let cards = viewModel.lesson.cards, !cards.isEmpty {
                    HStack {
                        Text("Types")
                            .font(CompanionPalette.captionFont())
                            .foregroundStyle(.secondary)

                        Spacer()

                        HStack(spacing: 8) {
                            ForEach(cardTypeBreakdown(), id: \.key) { type, count in
                                VStack(spacing: 2) {
                                    Image(systemName: cardTypeIcon(type))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(CompanionPalette.novaBlue)

                                    Text("\(count)")
                                        .font(CompanionPalette.smallCaptionFont())
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                }

                Divider()

                HStack {
                    Text("Difficulty")
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(difficultyText(viewModel.lesson.difficulty))
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(6)
        }
        .padding(12)
        .background(CompanionPalette.companionCard)
        .border(CompanionPalette.companionBorder, width: 1)
        .cornerRadius(8)
    }

    @ViewBuilder
    private func checklistSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pre-Publish Checklist")
                    .font(CompanionPalette.bodyFont())
                    .fontWeight(.semibold)

                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(viewModel.checklist) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.headline)
                            .foregroundStyle(colorForStatus(item.status))
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)

                            Text(item.description)
                                .font(CompanionPalette.captionFont())
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(CompanionPalette.companionCard)
                    .border(CompanionPalette.companionBorder, width: 1)
                    .cornerRadius(6)
                }
            }
        }
        .padding(12)
        .background(CompanionPalette.companionCard)
        .border(CompanionPalette.companionBorder, width: 1)
        .cornerRadius(8)
    }

    @ViewBuilder
    private func statusMessage() -> some View {
        switch viewModel.publishState {
        case .idle, .checking, .readyToPublish:
            EmptyView()

        case .generatingAssets:
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "waveform.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(CompanionPalette.novaOrange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Generating Assets")
                            .font(CompanionPalette.bodyFont())
                            .fontWeight(.semibold)

                        ProgressView(value: viewModel.assetProgress)
                            .tint(CompanionPalette.novaOrange)
                    }

                    Spacer()

                    Text("\(Int(viewModel.assetProgress * 100))%")
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)
                }
                .padding(12)
                .background(CompanionPalette.novaOrange.opacity(0.1))
                .cornerRadius(8)
            }

        case .publishing:
            VStack(spacing: 12) {
                HStack {
                    ProgressView()
                        .tint(CompanionPalette.novaBlue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Publishing")
                            .font(CompanionPalette.bodyFont())
                            .fontWeight(.semibold)

                        Text("This may take a moment...")
                            .font(CompanionPalette.captionFont())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(CompanionPalette.novaBlue.opacity(0.1))
                .cornerRadius(8)
            }

        case .completed:
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(CompanionPalette.novaGreen)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Published!")
                            .font(CompanionPalette.bodyFont())
                            .fontWeight(.semibold)

                        Text("\(childName) can now access this lesson")
                            .font(CompanionPalette.captionFont())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(CompanionPalette.novaGreen.opacity(0.1))
                .cornerRadius(8)
            }

        case .error(let message):
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unable to Publish")
                            .font(CompanionPalette.bodyFont())
                            .fontWeight(.semibold)

                        Text(message)
                            .font(CompanionPalette.captionFont())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    @ViewBuilder
    private func actionButtons() -> some View {
        VStack(spacing: 12) {
            switch viewModel.publishState {
            case .idle, .checking:
                EmptyView()

            case .readyToPublish:
                Button(action: {
                    Task {
                        await viewModel.publish()
                    }
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Publish Now")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(CompanionPalette.novaBlue)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
                    .font(CompanionPalette.bodyFont())
                }

                Button(action: {
                    Task {
                        await viewModel.publishWithAssets()
                    }
                }) {
                    HStack {
                        Image(systemName: "waveform.circle.fill")
                        Text("Generate Assets First")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(CompanionPalette.novaBlue.opacity(0.2))
                    .foregroundStyle(CompanionPalette.novaBlue)
                    .cornerRadius(8)
                    .font(CompanionPalette.bodyFont())
                }

            case .generatingAssets, .publishing:
                Button(action: {}) {
                    HStack {
                        ProgressView()
                            .tint(.white)

                        Text("Publishing...")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(CompanionPalette.novaBlue)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
                    .font(CompanionPalette.bodyFont())
                }
                .disabled(true)

            case .completed:
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Done")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(CompanionPalette.novaGreen)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
                    .font(CompanionPalette.bodyFont())
                }

            case .error:
                Button(action: { viewModel.runChecklist() }) {
                    Text("Try Again")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CompanionPalette.novaBlue)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                        .font(CompanionPalette.bodyFont())
                }

                Button(action: { dismiss() }) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(CompanionPalette.companionBorder))
                        .font(CompanionPalette.bodyFont())
                }
            }
        }
    }

    // MARK: - Helpers

    private func cardTypeBreakdown() -> [(key: Card.CardType, value: Int)] {
        guard let cards = viewModel.lesson.cards else { return [] }

        var breakdown: [Card.CardType: Int] = [:]
        for card in cards {
            breakdown[card.type, default: 0] += 1
        }

        return breakdown.sorted { $0.key.displayName < $1.key.displayName }
    }

    private func cardTypeIcon(_ type: Card.CardType) -> String {
        switch type {
        case .story: return "book.fill"
        case .concept: return "lightbulb.fill"
        case .experiment: return "puzzlepiece.fill"
        case .quiz: return "questionmark.circle"
        case .voice: return "mic.fill"
        case .video: return "play.rectangle.fill"
        }
    }

    private func colorForStatus(_ status: PublishFlowViewModel.ChecklistItem.Status) -> Color {
        switch status {
        case .passed:
            return CompanionPalette.novaGreen
        case .warning:
            return CompanionPalette.novaOrange
        case .failed:
            return .red
        }
    }

    private func difficultyText(_ difficulty: Int) -> String {
        switch difficulty {
        case 1: return "Easy"
        case 2: return "Medium"
        case 3: return "Hard"
        default: return "Unknown"
        }
    }
}

#Preview {
    PublishFlowView(
        lesson: Lesson(
            userId: UUID(),
            title: "AI Basics",
            description: "Learn about artificial intelligence",
            difficulty: 1,
            sortOrder: 1,
            cards: [
                Card(lessonId: UUID(), type: .story, sortOrder: 1, content: Card.CardContent(title: "Welcome")),
                Card(lessonId: UUID(), type: .concept, sortOrder: 2, content: Card.CardContent(title: "AI", explanation: "What is AI?")),
            ]
        )
    )
}
