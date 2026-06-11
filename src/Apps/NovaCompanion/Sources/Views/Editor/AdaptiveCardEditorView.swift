import SwiftUI
import NovaCore

/// Adaptive card editor that responds to device type (iPhone vs iPad).
/// iPad: Side-by-side layout with card list and form on left, live preview on right.
/// iPhone: Tab-based layout with Edit and Preview tabs, bottom card navigation.
public struct AdaptiveCardEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State var lesson: Lesson
    let onSave: (Lesson) -> Void

    @State private var selectedCardIndex: Int = 0
    @State private var showingPreview = false
    @State private var activeTab: Tab = .edit

    enum Tab {
        case edit
        case preview
    }

    var isIPad: Bool {
        horizontalSizeClass == .regular
    }

    var selectedCard: Card? {
        lesson.cards?[selectedCardIndex]
    }

    public var body: some View {
        NavigationStack {
            if isIPad {
                iPadLayout()
            } else {
                iPhoneLayout()
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - iPad Layout (Side-by-side)

    @ViewBuilder
    private func iPadLayout() -> some View {
        ZStack {
            CompanionPalette.companionBackground
                .ignoresSafeArea()

            HStack(spacing: 0) {
                // Left Panel: Card List + Editor Form
                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lesson.title)
                            .font(CompanionPalette.titleFont())
                            .lineLimit(1)

                        Text("Card \((selectedCardIndex + 1)) of \(lesson.cards?.count ?? 0)")
                            .font(CompanionPalette.secondaryBodyFont())
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(Color.white)
                    .border(CompanionPalette.companionBorder, width: 1)

                    Divider()

                    // Editor Content
                    HStack(spacing: 0) {
                        // Card List (Left Side)
                        CardListSidebar(
                            cards: $lesson.cards,
                            // Build-fix (Jun 11): the sidebar's selection is
                            // optional (nil = nothing selected); this editor
                            // always keeps a selection, so bridge nil → 0.
                            selectedCardIndex: Binding(
                                get: { selectedCardIndex },
                                set: { selectedCardIndex = $0 ?? 0 }
                            ),
                            lessonId: lesson.id
                        )
                        .frame(width: 280)
                        .background(CompanionPalette.companionBackground)

                        Divider()

                        // Form (Right Side)
                        if let card = selectedCard {
                            ScrollView {
                                CardFormView(card: .constant(card))
                                    .onChange(of: card) { _, newCard in
                                        if let index = lesson.cards?.firstIndex(where: { $0.id == card.id }) {
                                            lesson.cards?[index] = newCard
                                        }
                                    }
                                    .padding(16)
                            }
                            .background(Color.white)
                        } else {
                            emptyStateMessage()
                        }
                    }

                    Divider()

                    // Footer Buttons
                    HStack(spacing: 12) {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(CompanionPalette.companionBorder))
                        }

                        NavigationLink(destination: LessonPreviewView(lesson: lesson)) {
                            HStack {
                                Image(systemName: "eye")
                                Text("Preview Lesson")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(CompanionPalette.novaBlue.opacity(0.2))
                            .foregroundStyle(CompanionPalette.novaBlue)
                            .cornerRadius(8)
                        }

                        Button(action: { onSave(lesson); dismiss() }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save & Publish")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(CompanionPalette.novaBlue)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .border(CompanionPalette.companionBorder, width: 1)
                }

                Divider()

                // Right Panel: Live Preview
                VStack(spacing: 0) {
                    if let card = selectedCard {
                        CardPreviewView(card: card)
                    } else {
                        emptyStateMessage()
                    }
                }
                .frame(minWidth: 300)
                .background(Color.white)
            }
        }
        .navigationTitle("Edit Lesson")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - iPhone Layout (Tabbed)

    @ViewBuilder
    private func iPhoneLayout() -> some View {
        ZStack {
            CompanionPalette.companionBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(lesson.title)
                        .font(CompanionPalette.titleFont())
                        .lineLimit(1)

                    Text("Card \((selectedCardIndex + 1)) of \(lesson.cards?.count ?? 0)")
                        .font(CompanionPalette.secondaryBodyFont())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.white)
                .border(CompanionPalette.companionBorder, width: 1)

                // Tab Picker
                Picker("Tab", selection: $activeTab) {
                    Text("Edit").tag(Tab.edit)
                    Text("Preview").tag(Tab.preview)
                }
                .pickerStyle(.segmented)
                .padding(16)

                // Tab Content
                TabView(selection: $activeTab) {
                    editTabContent()
                        .tag(Tab.edit)

                    previewTabContent()
                        .tag(Tab.preview)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Divider()

                // Card Navigation (Bottom)
                cardNavigation()
                    .padding(16)
                    .background(Color.white)
                    .border(CompanionPalette.companionBorder, width: 1)

                // Footer Buttons
                HStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(CompanionPalette.companionBorder))
                    }

                    NavigationLink(destination: LessonPreviewView(lesson: lesson)) {
                        Image(systemName: "eye")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(CompanionPalette.novaBlue.opacity(0.2))
                            .foregroundStyle(CompanionPalette.novaBlue)
                            .cornerRadius(8)
                    }

                    Button(action: { onSave(lesson); dismiss() }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save")
                        }
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
        .navigationTitle("Edit Lesson")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func editTabContent() -> some View {
        ZStack {
            CompanionPalette.companionBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if let card = selectedCard {
                    ScrollView {
                        CardFormView(card: .constant(card))
                            .onChange(of: card) { _, newCard in
                                if let index = lesson.cards?.firstIndex(where: { $0.id == card.id }) {
                                    lesson.cards?[index] = newCard
                                }
                            }
                            .padding(16)
                    }
                } else {
                    emptyStateMessage()
                }
            }
        }
    }

    @ViewBuilder
    private func previewTabContent() -> some View {
        ZStack {
            CompanionPalette.companionBackground
                .ignoresSafeArea()

            ScrollView {
                if let card = selectedCard {
                    CardPreviewView(card: card)
                } else {
                    emptyStateMessage()
                }
            }
        }
    }

    @ViewBuilder
    private func cardNavigation() -> some View {
        VStack(spacing: 12) {
            // Card List Picker
            if let cards = lesson.cards, !cards.isEmpty {
                Menu {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        Button(action: { selectedCardIndex = index }) {
                            HStack {
                                Text("\(index + 1). \(card.type.displayName)")
                                if selectedCardIndex == index {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.stack")
                        Text("Select Card")
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(CompanionPalette.companionCard)
                    .border(CompanionPalette.companionBorder, width: 1)
                    .cornerRadius(8)
                }
            }

            // Previous/Next Buttons
            HStack(spacing: 12) {
                Button(action: { moveCard(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedCardIndex > 0 ? CompanionPalette.companionCard : CompanionPalette.companionBackground)
                        .border(CompanionPalette.companionBorder, width: 1)
                        .cornerRadius(8)
                }
                .disabled(selectedCardIndex == 0)

                Text("\(selectedCardIndex + 1) / \(lesson.cards?.count ?? 0)")
                    .font(CompanionPalette.bodyFont())
                    .frame(maxWidth: .infinity)

                Button(action: { moveCard(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background((lesson.cards?.count ?? 0) > selectedCardIndex + 1 ? CompanionPalette.companionCard : CompanionPalette.companionBackground)
                        .border(CompanionPalette.companionBorder, width: 1)
                        .cornerRadius(8)
                }
                .disabled((lesson.cards?.count ?? 0) <= selectedCardIndex + 1)
            }
        }
    }

    @ViewBuilder
    private func emptyStateMessage() -> some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.pencil")
                .font(.title.weight(.light))
                .foregroundStyle(.gray)

            Text("No cards yet")
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)

            Text("Add your first card to get started")
                .font(CompanionPalette.captionFont())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CompanionPalette.companionBackground)
    }

    private func moveCard(by offset: Int) {
        selectedCardIndex += offset
        selectedCardIndex = max(0, min(selectedCardIndex, (lesson.cards?.count ?? 1) - 1))
    }
}

#Preview {
    AdaptiveCardEditorView(
        lesson: Lesson(
            userId: UUID(),
            title: "Sample Lesson",
            description: "A test lesson",
            difficulty: 1,
            sortOrder: 1,
            cards: [
                Card(lessonId: UUID(), type: .concept, sortOrder: 1, content: Card.CardContent(title: "First Card")),
                Card(lessonId: UUID(), type: .quiz, sortOrder: 2, content: Card.CardContent(question: "What is AI?")),
            ]
        ),
        onSave: { _ in }
    )
}
