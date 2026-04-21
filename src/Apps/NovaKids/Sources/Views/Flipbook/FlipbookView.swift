import SwiftUI
import NovaCore
import NovaVoice

/// Full-screen flipbook view for card navigation.
///
/// Displays cards with horizontal swipe navigation using TabView page style.
/// Includes progress tracking, progress dots, and back button.
public struct FlipbookView: View {
    /// The lesson to display.
    let lesson: Lesson

    @StateObject private var viewModel: FlipbookViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var voiceManager: VoiceManager

    public init(lesson: Lesson) {
        self.lesson = lesson
        // Initialize with a default voice manager; will be overridden by environment
        _viewModel = StateObject(wrappedValue: FlipbookViewModel(
            lesson: lesson,
            voiceManager: VoiceManager(speechSynthesizer: SpeechSynthesizer())
        ))
    }

    public var body: some View {
        ZStack {
            NovaPalette.novaBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                FlipbookHeader(lesson: lesson) {
                    dismiss()
                }
                .padding(20)

                Spacer()

                // Card display with TabView for swiping
                if !viewModel.cards.isEmpty {
                    ZStack(alignment: .topTrailing) {
                        TabView(selection: $viewModel.currentCardIndex) {
                            ForEach(0..<viewModel.cards.count, id: \.self) { index in
                                let card = viewModel.cards[index]

                                ZStack {
                                    if card.type == .story {
                                        StoryCardView(card: card)
                                    } else if card.type == .concept {
                                        ConceptCardView(card: card)
                                    } else if card.type == .experiment {
                                        ExperimentCardView(card: card)
                                    } else if card.type == .quiz {
                                        QuizCardView(card: card)
                                    } else if card.type == .voice {
                                        VoiceCardView(card: card)
                                    } else {
                                        // Fallback for other card types
                                        ZStack {
                                            NovaPalette.novaBlue.opacity(0.2)
                                            VStack {
                                                Image(systemName: "questionmark.circle")
                                                    .font(.largeTitle)
                                                    .foregroundStyle(NovaPalette.novaBlue)
                                                    .accessibilityHidden(true)
                                                Text("Card Type: \(card.type.rawValue)")
                                                    .font(NovaPalette.bodyFont())
                                                    .foregroundStyle(.primary)
                                            }
                                        }
                                    }
                                }
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    )
                                )
                                .tag(index)
                                .onAppear {
                                    viewModel.markCurrentCardComplete()
                                }
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .indexViewStyle(.page(backgroundDisplayMode: .never))
                        .padding(20)

                        // Dashy Hint Button - top right
                        DashyHintButton(showHintSheet: $viewModel.showDashyHint)
                            .padding(20)
                    }
                } else {
                    EmptyStateView(
                        title: "No cards",
                        subtitle: "This lesson has no content yet",
                        icon: "exclamationmark.circle"
                    )
                }

                Spacer()

                // Progress dots
                if !viewModel.cards.isEmpty {
                    CardProgressDots(
                        currentIndex: viewModel.currentCardIndex,
                        totalCards: viewModel.cards.count
                    )
                    .padding(20)
                }

                // Navigation buttons
                if !viewModel.cards.isEmpty {
                    HStack(spacing: 16) {
                        // Previous button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.previousCard()
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.headline)
                                    .accessibilityHidden(true)
                                Text("Previous")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                viewModel.currentCardIndex > 0
                                    ? NovaPalette.ink.opacity(0.1)
                                    : NovaPalette.ink.opacity(0.05)
                            )
                            .foregroundStyle(
                                viewModel.currentCardIndex > 0
                                    ? .primary
                                    : .secondary
                            )
                            .cornerRadius(10)
                        }
                        .disabled(viewModel.currentCardIndex == 0)

                        // Next button
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.nextCard()
                            }
                        }) {
                            HStack(spacing: 8) {
                                if viewModel.isLastCard {
                                    Text("Finish")
                                } else {
                                    Text("Next")
                                }
                                Image(systemName: viewModel.isLastCard ? "checkmark.circle.fill" : "chevron.right")
                                    .font(.headline)
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                viewModel.currentCardIndex < viewModel.cards.count - 1
                                    ? NovaPalette.novaOrange
                                    : NovaPalette.novaGreen
                            )
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                        }
                        .disabled(viewModel.isLastCard)
                    }
                    .padding(20)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Flipbook viewer")
        .accessibilityValue("Card \(viewModel.currentCardIndex + 1) of \(viewModel.cards.count)")
        .sheet(isPresented: $viewModel.showDashyHint) {
            DashyHintSheet(hintText: viewModel.currentHint)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    let lesson = Lesson(
        id: UUID(),
        pathId: UUID(),
        userId: UUID(),
        title: "What Makes AI Smart?",
        description: "Learn how artificial intelligence learns from data",
        thumbnailURL: nil,
        difficulty: 1,
        sourceURL: nil,
        aiAnalysis: nil,
        status: .published,
        sortOrder: 1,
        createdAt: Date(),
        publishedAt: Date(),
        cards: []
    )

    NavigationStack {
        FlipbookView(lesson: lesson)
    }
}
