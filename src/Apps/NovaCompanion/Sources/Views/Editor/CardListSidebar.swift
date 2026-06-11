import SwiftUI
import NovaCore

/// Reorderable card list sidebar for the adaptive editor.
/// Displays cards with drag handles, selection highlighting, and deletion support.
public struct CardListSidebar: View {
    @Binding var cards: [Card]?
    @Binding var selectedCardIndex: Int?
    let lessonId: UUID
    @State private var deletingIndex: Int?

    public var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Cards")
                    .font(CompanionPalette.bodyFont())
                    .fontWeight(.semibold)

                Spacer()

                Text("\(cards?.count ?? 0)")
                    .font(CompanionPalette.captionFont())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Card List
            if let cards = cards, !cards.isEmpty {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            cardListItemButton(index: index, card: card)
                        }
                        .onMove { from, to in
                            // Build-fix (Jun 11): `cards` here is the
                            // immutable `if let` shadow — mutate through
                            // the binding instead.
                            var reordered = cards
                            reordered.move(fromOffsets: from, toOffset: to)
                            for i in reordered.indices {
                                reordered[i].sortOrder = i + 1
                            }
                            self.cards = reordered
                        }
                    }
                    .padding(.horizontal, 16)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "square.and.pencil")
                        .font(.title2.weight(.light))
                        .foregroundStyle(.gray)

                    Text("No cards yet")
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(CompanionPalette.companionCard)
                .border(CompanionPalette.companionBorder, width: 1)
                .cornerRadius(8)
                .padding(.horizontal, 16)
            }

            // Add Card Button
            Button(action: addCard) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Card")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(CompanionPalette.novaBlue)
                .foregroundStyle(.white)
                .cornerRadius(8)
                .font(CompanionPalette.bodyFont())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(CompanionPalette.companionBackground)
    }

    @ViewBuilder
    private func cardListItemButton(index: Int, card: Card) -> some View {
        Button(action: { selectedCardIndex = index }) {
            HStack(spacing: 12) {
                // Drag Handle
                Image(systemName: "line.3.horizontal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                // Type Icon
                Image(systemName: cardTypeIcon(card.type))
                    .font(.headline)
                    .foregroundStyle(CompanionPalette.novaBlue)

                // Content Preview
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.type.displayName)
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)

                    Text(card.content.title ?? card.content.explanation ?? "Untitled")
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Sort Order Badge
                Text("\(card.sortOrder)")
                    .font(CompanionPalette.smallCaptionFont())
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(CompanionPalette.novaBlue.opacity(0.7))
                    .clipShape(Circle())

                // Delete Menu
                Menu {
                    Button(role: .destructive, action: { deletingIndex = index }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(selectedCardIndex == index ? CompanionPalette.novaBlue.opacity(0.1) : CompanionPalette.companionCard)
            .border(
                selectedCardIndex == index ?
                CompanionPalette.novaBlue :
                CompanionPalette.companionBorder,
                width: 1
            )
            .cornerRadius(8)
        }
        .foregroundStyle(.primary)
        .confirmationDialog(
            "Delete Card",
            isPresented: .constant(deletingIndex == index),
            presenting: index,
            actions: { index in
                Button("Delete", role: .destructive) {
                    cards?.remove(at: index)
                    deletingIndex = nil
                    // Reset selection if we deleted the selected card
                    if selectedCardIndex == index {
                        selectedCardIndex = nil
                    }
                }
            },
            message: { _ in
                Text("Are you sure you want to delete this card? This action cannot be undone.")
            }
        )
    }

    private func cardTypeIcon(_ type: Card.CardType) -> String {
        switch type {
        case .story:
            return "book.fill"
        case .concept:
            return "lightbulb.fill"
        case .experiment:
            return "puzzlepiece.fill"
        case .quiz:
            return "questionmark.circle"
        case .voice:
            return "mic.fill"
        case .video:
            return "play.rectangle.fill"
        }
    }

    private func addCard() {
        let newCard = Card(
            lessonId: lessonId,
            type: .concept,
            sortOrder: (cards?.count ?? 0) + 1,
            content: Card.CardContent()
        )
        if cards == nil {
            cards = []
        }
        cards?.append(newCard)
        selectedCardIndex = (cards?.count ?? 1) - 1
    }
}

#Preview {
    CardListSidebar(
        cards: .constant(mockCards()),
        selectedCardIndex: .constant(0),
        lessonId: UUID()
    )
}

func mockCards() -> [Card] {
    [
        Card(
            lessonId: UUID(),
            type: .story,
            sortOrder: 1,
            content: Card.CardContent(title: "The Beginning")
        ),
        Card(
            lessonId: UUID(),
            type: .concept,
            sortOrder: 2,
            content: Card.CardContent(title: "AI Basics", explanation: "What is artificial intelligence?")
        ),
        Card(
            lessonId: UUID(),
            type: .quiz,
            sortOrder: 3,
            content: Card.CardContent(question: "What is AI?")
        ),
    ]
}
