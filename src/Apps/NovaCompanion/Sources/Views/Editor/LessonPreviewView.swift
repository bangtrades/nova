import SwiftUI
import NovaCore

/// Full lesson preview that simulates the Kids app flipbook experience.
/// Allows navigation through all cards with swipe or button controls.
public struct LessonPreviewView: View {
    @Environment(\.dismiss) var dismiss

    let lesson: Lesson
    @State private var currentCardIndex = 0

    var cards: [Card] {
        lesson.cards ?? []
    }

    var currentCard: Card? {
        cards.indices.contains(currentCardIndex) ? cards[currentCardIndex] : nil
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Nova Kids background (simulating the Kids app)
                NovaPalette.novaBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header with Exit Button
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Exit Preview")
                            }
                            .font(CompanionPalette.bodyFont())
                            .foregroundStyle(CompanionPalette.novaBlue)
                        }

                        Spacer()

                        // Lesson Title
                        Text(lesson.title)
                            .font(NovaPalette.headingFont())
                            .fontWeight(.bold)
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(16)
                    .background(Color.white)
                    .border(CompanionPalette.companionBorder, width: 1)

                    // Card Preview
                    if let card = currentCard {
                        ZStack {
                            NovaPalette.novaBackground
                                .ignoresSafeArea()

                            VStack {
                                CardPreviewView(card: card)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                    } else {
                        emptyState()
                    }

                    // Progress Indicator
                    HStack(spacing: 8) {
                        ForEach(0..<cards.count, id: \.self) { index in
                            Capsule()
                                .frame(height: 6)
                                .foregroundStyle(
                                    index == currentCardIndex ?
                                    NovaPalette.novaBlue :
                                    NovaPalette.novaBlue.opacity(0.3)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    // Navigation Controls
                    HStack(spacing: 12) {
                        Button(action: { moveCard(by: -1) }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(
                                    currentCardIndex > 0 ?
                                    NovaPalette.novaBlue :
                                    NovaPalette.novaBlue.opacity(0.3)
                                )
                        }
                        .disabled(currentCardIndex == 0)

                        Spacer()

                        VStack(spacing: 4) {
                            Text("Card")
                                .font(NovaPalette.captionFont())
                                .foregroundStyle(.secondary)

                            Text("\(currentCardIndex + 1) of \(cards.count)")
                                .font(NovaPalette.headingFont())
                                .fontWeight(.bold)
                        }

                        Spacer()

                        Button(action: { moveCard(by: 1) }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(
                                    currentCardIndex < cards.count - 1 ?
                                    NovaPalette.novaBlue :
                                    NovaPalette.novaBlue.opacity(0.3)
                                )
                        }
                        .disabled(currentCardIndex >= cards.count - 1)
                    }
                    .padding(16)
                    .background(Color.white)
                    .border(CompanionPalette.companionBorder, width: 1)
                }
            }
            .navigationBarBackButtonHidden(true)
            .gesture(
                DragGesture()
                    .onEnded { gesture in
                        if gesture.translation.width > 100 {
                            moveCard(by: -1)
                        } else if gesture.translation.width < -100 {
                            moveCard(by: 1)
                        }
                    }
            )
        }
    }

    @ViewBuilder
    private func emptyState() -> some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.pencil")
                .font(.largeTitle.weight(.light))
                .foregroundStyle(.gray)

            Text("No cards to preview")
                .font(NovaPalette.headingFont())
                .fontWeight(.bold)

            Text("Add cards to this lesson to see a preview")
                .font(NovaPalette.bodyFont())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NovaPalette.novaBackground)
    }

    private func moveCard(by offset: Int) {
        let newIndex = currentCardIndex + offset
        if newIndex >= 0 && newIndex < cards.count {
            currentCardIndex = newIndex
        }
    }
}

#Preview {
    NavigationStack {
        LessonPreviewView(
            lesson: Lesson(
                userId: UUID(),
                title: "AI Basics",
                description: "Learn about artificial intelligence",
                difficulty: 1,
                sortOrder: 1,
                cards: [
                    Card(
                        lessonId: UUID(),
                        type: .story,
                        sortOrder: 1,
                        content: Card.CardContent(
                            title: "Welcome to AI",
                            narrativeText: "Let's explore the world of artificial intelligence together!"
                        )
                    ),
                    Card(
                        lessonId: UUID(),
                        type: .concept,
                        sortOrder: 2,
                        content: Card.CardContent(
                            title: "What is AI?",
                            explanation: "Artificial Intelligence is the ability of computers to learn and solve problems."
                        )
                    ),
                    Card(
                        lessonId: UUID(),
                        type: .quiz,
                        sortOrder: 3,
                        content: Card.CardContent(
                            question: "Which of these is an AI?",
                            options: [
                                Card.QuizOption(id: "1", text: "A smartphone"),
                                Card.QuizOption(id: "2", text: "A chatbot"),
                                Card.QuizOption(id: "3", text: "A light bulb"),
                            ],
                            correctOptionIndex: 1
                        )
                    ),
                ]
            )
        )
    }
}
