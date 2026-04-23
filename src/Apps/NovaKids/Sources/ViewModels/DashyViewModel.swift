import Foundation
import Combine
import NovaCore
import NovaVoice
import Speech

/// Dashy chat conversation state machine.
public enum DashyState: Equatable {
    case ready
    case listening
    case processing
    case responding
    case error(String)
}

/// Dashy's emotional expression mapped to character animation states.
public enum DashyEmotion: String, Codable {
    case happy
    case curious
    case excited
    case thinking
}

/// Single chat message in conversation history.
///
/// > Wire-protocol note: `role` carries the server-side literal. As of S12-07/08
/// > the backend under `services/dashy/` and this iOS VM flipped together to
/// > the "dashy" literal in a single coordinated commit range — no in-flight
/// > skew because bang owns both client and server and the only live client
/// > is his iPad.
public struct ChatMessage: Identifiable, Codable {
    public let id: UUID
    public let role: String  // "user" or "dashy" (wire protocol)
    public let content: String
    public let timestamp: Date
    public let emotion: String?  // Optional emotion from API

    public init(
        id: UUID = UUID(),
        role: String,
        content: String,
        timestamp: Date = Date(),
        emotion: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.emotion = emotion
    }
}

/// View model managing Dashy voice conversation and state.
@MainActor
public class DashyViewModel: NSObject, ObservableObject {
    // MARK: - Published Properties

    /// Current state of the conversation.
    @Published public var state: DashyState = .ready

    /// Conversation history (max 10 messages).
    @Published public var conversationHistory: [ChatMessage] = []

    /// Current emotional expression for character animation.
    @Published public var currentEmotion: DashyEmotion = .happy

    /// Suggested follow-up questions from the API.
    @Published public var suggestions: [String] = []

    /// Error message for display.
    @Published public var errorMessage: String?

    /// Progress indicator (0-1) for response processing.
    @Published public var processingProgress: Double = 0

    // MARK: - Private Properties

    private let apiRouter: APIRouter
    private let voiceManager: VoiceManager
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var isRecordingAudio = false
    private var cancellables = Set<AnyCancellable>()

    // Constants
    private let maxHistorySize = 10
    private let maxSuggestions = 4

    // MARK: - Initialization

    public init(apiRouter: APIRouter, voiceManager: VoiceManager) {
        self.apiRouter = apiRouter
        self.voiceManager = voiceManager
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()

        // Request speech recognition authorization on init
        SFSpeechRecognizer.requestAuthorization { _ in
            // Authorization status updated
        }
    }

    // MARK: - Public Methods

    /// Begins listening for voice input.
    public func startListening() {
        guard state == .ready else { return }
        guard speechRecognizer?.isAvailable == true else {
            setState(.error("Speech recognition not available"))
            return
        }

        state = .listening
        isRecordingAudio = true

        do {
            if recognitionRequest != nil {
                recognitionRequest = nil
                recognitionTask = nil
            }

            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                setState(.error("Failed to create recognition request"))
                return
            }

            recognitionRequest.shouldReportPartialResults = true

            if !audioEngine.isRunning {
                try audioEngine.start()
            }

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }

            recognitionTask = speechRecognizer?.recognitionTask(
                with: recognitionRequest
            ) { [weak self] result, error in
                self?.handleRecognitionResult(result, error: error)
            }
        } catch {
            setState(.error("Audio session setup failed"))
        }
    }

    /// Stops listening and sends transcript to API.
    public func stopListening() {
        guard state == .listening else { return }

        isRecordingAudio = false
        audioEngine.inputNode.removeTap(onBus: 0)

        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }

        // Don't change state here — let recognition task complete
    }

    /// Sends a text message to Dashy.
    /// - Parameter text: The user's message.
    public func sendMessage(text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        guard state == .ready else { return }

        let userMessage = ChatMessage(role: "user", content: text)
        addMessageToHistory(userMessage)

        Task {
            await fetchDashyResponse(userMessage: text)
        }
    }

    /// Clears conversation history.
    public func clearHistory() {
        conversationHistory.removeAll()
        suggestions.removeAll()
        currentEmotion = .happy
    }

    // MARK: - Private Methods

    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            setState(.error("Listening failed: \(error.localizedDescription)"))
            return
        }

        guard let result = result else { return }

        if result.isFinal {
            let transcript = result.bestTranscription.formattedString
            audioEngine.inputNode.removeTap(onBus: 0)

            if !audioEngine.isRunning {
                audioEngine.stop()
            }

            state = .processing
            isRecordingAudio = false

            // Send the transcript to Dashy
            Task {
                await fetchDashyResponse(userMessage: transcript)
            }
        }
    }

    /// Decoded response shape from `POST /api/v1/dashy/chat`.
    /// Kept at type scope (not nested inside `fetchDashyResponse`) so the
    /// Swift 6 decoder doesn't drag an async-context generic binding across
    /// a function body every call.
    private struct DashyResponse: Decodable {
        let message: String
        let emotion: String?
        let suggestions: [String]?
    }

    private func fetchDashyResponse(userMessage: String) async {
        state = .processing

        // Build the history payload in the wire shape the backend expects:
        // an array of `{role, content}` dicts, one per message in the
        // rolling 10-message window. `dashyChat` takes `[[String: String]]`
        // because `[String: Any]` isn't `Encodable`.
        let historyPayload: [[String: String]] = conversationHistory.map { message in
            ["role": message.role, "content": message.content]
        }

        do {
            state = .responding

            // Kick the progress ring to ~0.3 immediately so the user sees
            // motion while the network round-trip is in flight. The API
            // call is the actual long pole; the decorative animation runs
            // alongside rather than padding the delay.
            processingProgress = 0.3

            // S11-19: real API call replaces the simulated response.
            // S12-07/08: endpoint path + role literal both flipped to "dashy"
            // in a single coordinated commit range alongside the backend
            // service rename — no in-flight skew.
            let response: DashyResponse = try await apiRouter.request(
                .dashyChat(message: userMessage, history: historyPayload)
            )

            processingProgress = 0.8

            // Dashy's reply message, stamped with the server-side emotion
            // when present so the character animation has a signal.
            let dashyMessage = ChatMessage(
                role: "dashy",
                content: response.message,
                emotion: response.emotion
            )

            addMessageToHistory(dashyMessage)
            updateEmotion(from: response.emotion ?? "happy")

            // Follow-up prompts — server may return nil (older backend) or
            // an empty array (nothing to suggest). Capped at `maxSuggestions`
            // so a chatty model can't flood the carousel.
            let incoming = response.suggestions ?? []
            suggestions = Array(incoming.prefix(maxSuggestions))

            // Play Dashy's response via voice manager. `preferRemote: false`
            // uses on-device TTS for latency.
            try await voiceManager.speak(text: response.message, preferRemote: false)

            processingProgress = 1.0
            state = .ready
            processingProgress = 0
            errorMessage = nil
        } catch let error as APIError {
            // Surface the semantic reason so the UI can say "Dashy is
            // offline" vs "no network" vs "Dashy is taking a break"
            // accurately. The chat view's error pill reads `errorMessage`.
            setState(.error(error.errorDescription ?? "Dashy is thinking..."))
            processingProgress = 0
        } catch {
            setState(.error("Oops! Dashy is thinking... try again soon!"))
            processingProgress = 0
        }
    }

    private func addMessageToHistory(_ message: ChatMessage) {
        conversationHistory.append(message)

        // Keep only last 10 messages
        if conversationHistory.count > maxHistorySize {
            conversationHistory.removeFirst(conversationHistory.count - maxHistorySize)
        }
    }

    private func updateEmotion(from emotionString: String) {
        if let emotion = DashyEmotion(rawValue: emotionString) {
            currentEmotion = emotion
        }
    }

    private func setState(_ newState: DashyState) {
        state = newState
        if case let .error(message) = newState {
            errorMessage = message
        }
    }
}

/// Helper for encoding arbitrary dictionaries as Codable.
private struct AnyCodable: Encodable {
    let value: [String: Any]

    init(_ value: [String: Any]) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        for (key, value) in value {
            let dynamicKey = DynamicKey(stringValue: key)!
            if let intValue = value as? Int {
                try container.encode(intValue, forKey: dynamicKey)
            } else if let stringValue = value as? String {
                try container.encode(stringValue, forKey: dynamicKey)
            } else if let doubleValue = value as? Double {
                try container.encode(doubleValue, forKey: dynamicKey)
            } else if let boolValue = value as? Bool {
                try container.encode(boolValue, forKey: dynamicKey)
            }
        }
    }

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = String(intValue)
        }
    }
}
