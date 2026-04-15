import SwiftUI
import NovaCore
import NovaVoice

/// Full voice chat interface with animated Sparky character.
///
/// Central Sparky character with 4 animation states, conversation history,
/// large talk button, and suggested follow-up questions.
public struct SparkyView: View {
    @StateObject private var viewModel: SparkyViewModel
    @EnvironmentObject var apiRouter: APIRouter
    @EnvironmentObject var voiceManager: VoiceManager

    @State private var animationState: SparkyAnimationState = .idle
    @State private var inputText: String = ""
    @State private var showCelebration: Bool = false
    @State private var celebrationTask: Task<Void, Never>?

    public init() {
        // Placeholder initialization — will be injected by parent
        _viewModel = StateObject(wrappedValue: SparkyViewModel(
            apiRouter: APIRouter(apiClient: APIClient(
                baseURL: URL(string: "https://api.nova.local")!,
                tokenProvider: EmptyTokenProvider()
            )),
            voiceManager: VoiceManager(speechSynthesizer: SpeechSynthesizer())
        ))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                NovaPalette.novaBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Talk to Sparky")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Ask me anything about AI and learning!")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 16)

                    Divider()
                        .padding(.horizontal, 20)

                    // Conversation area
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            // Chat history
                            ForEach(viewModel.conversationHistory) { message in
                                chatBubble(message)
                            }

                            // Character and responses
                            VStack(spacing: 20) {
                                // Sparky character
                                SparkyCharacterView(state: $animationState)
                                    .frame(height: 200)
                                    .padding(.horizontal, 40)

                                // Processing indicator
                                if viewModel.state == .responding {
                                    VStack(spacing: 8) {
                                        ProgressView(value: viewModel.processingProgress)
                                            .tint(NovaPalette.novaOrange)
                                            .frame(height: 4)

                                        Text("Sparky is thinking...")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 40)
                                }

                                // Suggestions
                                if !viewModel.suggestions.isEmpty && viewModel.state == .ready {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Try asking:")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 20)

                                        VStack(spacing: 8) {
                                            ForEach(viewModel.suggestions.indices, id: \.self) { index in
                                                let suggestion = viewModel.suggestions[index]
                                                Button(action: { viewModel.sendMessage(text: suggestion) }) {
                                                    HStack {
                                                        Text(suggestion)
                                                            .font(NovaPalette.bodyFont())
                                                            .foregroundStyle(.primary)

                                                        Spacer()

                                                        Image(systemName: "arrow.right")
                                                            .foregroundStyle(NovaPalette.novaOrange)
                                                    }
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 10)
                                                    .background(NovaPalette.novaCardBackground)
                                                    .cornerRadius(8)
                                                    .shadow(
                                                        color: Color.black.opacity(0.05),
                                                        radius: 2,
                                                        x: 0,
                                                        y: 1
                                                    )
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                    .padding(.vertical, 12)
                                }

                                // Starter prompts (when no conversation)
                                if viewModel.conversationHistory.isEmpty && viewModel.state == .ready {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("What should I ask?")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 20)

                                        let starterPrompts = [
                                            "What is AI?",
                                            "How do robots learn?",
                                            "Can you teach me something new?",
                                            "Tell me a fun fact!"
                                        ]
                                        VStack(spacing: 8) {
                                            ForEach(starterPrompts.indices, id: \.self) { index in
                                                let prompt = starterPrompts[index]
                                                Button(action: { viewModel.sendMessage(text: prompt) }) {
                                                    Text(prompt)
                                                        .font(NovaPalette.bodyFont())
                                                        .foregroundStyle(.primary)
                                                        .frame(maxWidth: .infinity)
                                                        .padding(.vertical, 12)
                                                        .background(
                                                            LinearGradient(
                                                                gradient: Gradient(colors: [
                                                                    NovaPalette.novaOrange.opacity(0.2),
                                                                    NovaPalette.novaPurple.opacity(0.2)
                                                                ]),
                                                                startPoint: .topLeading,
                                                                endPoint: .bottomTrailing
                                                            )
                                                        )
                                                        .cornerRadius(8)
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                    .padding(.vertical, 12)
                                }

                                // Error message
                                if case let .error(message) = viewModel.state {
                                    VStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(NovaPalette.novaPink)

                                        Text(message)
                                            .font(NovaPalette.bodyFont())
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.center)

                                        Button(action: { viewModel.clearHistory() }) {
                                            Text("Try Again")
                                                .font(NovaPalette.smallHeadingFont())
                                                .foregroundStyle(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(NovaPalette.novaPink)
                                                .cornerRadius(8)
                                        }
                                    }
                                    .padding(20)
                                    .background(NovaPalette.novaCardBackground)
                                    .cornerRadius(12)
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.vertical, 20)
                    }

                    Divider()
                        .padding(.horizontal, 20)

                    // Input and microphone area
                    VStack(spacing: 16) {
                        // Text input
                        HStack(spacing: 12) {
                            TextField("Type your question...", text: $inputText)
                                .font(NovaPalette.bodyFont())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(NovaPalette.novaCardBackground)
                                .cornerRadius(8)

                            Button(action: {
                                if !inputText.isEmpty {
                                    viewModel.sendMessage(text: inputText)
                                    inputText = ""
                                }
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 48, height: 48)
                                    .background(NovaPalette.novaOrange)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 20)

                        // Talk button (primary action)
                        Button(action: {
                            if viewModel.state == .listening {
                                viewModel.stopListening()
                                animationState = .idle
                            } else if viewModel.state == .ready {
                                viewModel.startListening()
                                animationState = .listening
                            }
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: viewModel.state == .listening ? "mic.fill" : "mic")
                                    .font(.title3)

                                Text(viewModel.state == .listening ? "Release to Send" : "Talk to Sparky")
                                    .font(NovaPalette.smallHeadingFont())
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        viewModel.state == .listening
                                            ? NovaPalette.novaOrange
                                            : NovaPalette.novaPurple,
                                        viewModel.state == .listening
                                            ? NovaPalette.novaPurple
                                            : NovaPalette.novaBlue
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        .disabled(viewModel.state == .processing || viewModel.state == .responding)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: viewModel.state) { _, newState in
                updateAnimationState(newState)
            }
            .onChange(of: viewModel.currentEmotion) { _, emotion in
                updateAnimationFromEmotion(emotion)
            }
            .onDisappear {
                celebrationTask?.cancel()
            }
        }
    }

    // MARK: - Subviews

    private func chatBubble(_ message: ChatMessage) -> some View {
        HStack(spacing: 12) {
            if message.role == "sparky" {
                // Sparky message (left-aligned)
                HStack(spacing: 8) {
                    // Avatar
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(NovaPalette.novaPurple)
                        .cornerRadius(16)

                    // Message bubble
                    Text(message.content)
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(NovaPalette.novaPurple.opacity(0.15))
                        .cornerRadius(12)

                    Spacer()
                }
            } else {
                // User message (right-aligned)
                HStack(spacing: 0) {
                    Spacer()

                    Text(message.content)
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(NovaPalette.novaBlue)
                        .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func updateAnimationState(_ state: SparkyState) {
        switch state {
        case .ready:
            animationState = .idle
        case .listening:
            animationState = .listening
        case .processing:
            animationState = .thinking
        case .responding:
            animationState = .talking
        case .error:
            animationState = .idle
        }
    }

    private func updateAnimationFromEmotion(_ emotion: SparkyEmotion) {
        switch emotion {
        case .happy, .excited:
            withAnimation { showCelebration = true }
            celebrationTask?.cancel()
            celebrationTask = Task {
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard !Task.isCancelled else { return }
                withAnimation { showCelebration = false }
            }
        default:
            break
        }
    }
}

// MARK: - Empty Token Provider

private class EmptyTokenProvider: TokenProvider {
    var accessToken: String? {
        get async { nil }
    }

    var refreshToken: String? {
        get async { nil }
    }

    func updateTokens(accessToken: String, refreshToken: String) async {}
    func clearTokens() async {}
}

#Preview {
    SparkyView()
        .environmentObject(VoiceManager(speechSynthesizer: SpeechSynthesizer()))
}
