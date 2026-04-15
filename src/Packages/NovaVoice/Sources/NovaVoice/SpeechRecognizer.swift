import Foundation
import Speech
import AVFoundation
import Combine

/// Recognizes speech input from the microphone.
///
/// Wraps SFSpeechRecognizer to provide voice input for interactive lessons.
/// Handles microphone authorization and continuous transcription.
@MainActor
public class SpeechRecognizer: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    /// Current transcribed text.
    @Published public var transcript: String = ""

    /// Whether the recognizer is currently listening.
    @Published public var isListening: Bool = false

    /// Last error encountered.
    @Published public var lastError: Error?

    /// Speech recognizer instance.
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    /// Speech recognition request.
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    /// Recognition task.
    private var recognitionTask: SFSpeechRecognitionTask?

    /// Audio engine.
    private let audioEngine = AVAudioEngine()

    /// Initialize a new SpeechRecognizer.
    public override init() {
        super.init()
        recognizer?.delegate = self
    }

    /// Starts listening for speech input.
    ///
    /// Returns an AsyncStream that emits transcript updates as the user speaks.
    ///
    /// - Returns: AsyncStream<String> emitting partial transcripts.
    /// - Throws: SpeechError if microphone access is denied or setup fails.
    public func startListening() async throws -> AsyncStream<String> {
        // Request microphone access
        let micGranted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        guard micGranted else {
            throw SpeechError.authorizationDenied
        }

        // Request speech recognition access
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            throw SpeechError.authorizationDenied
        }

        // Reset state
        transcript = ""
        lastError = nil

        return AsyncStream { continuation in
            do {
                try self.setupAudioEngine()

                let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
                recognitionRequest.shouldReportPartialResults = true
                self.recognitionRequest = recognitionRequest

                let recognitionTask = self.recognizer?.recognitionTask(with: recognitionRequest) { result, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self.lastError = error
                            self.isListening = false
                        }
                        continuation.finish()
                        return
                    }

                    guard let result = result else {
                        return
                    }

                    let transcript = result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        self.transcript = transcript
                        continuation.yield(transcript)

                        if result.isFinal {
                            self.stopListeningInternal()
                            continuation.finish()
                        }
                    }
                }

                self.recognitionTask = recognitionTask

                DispatchQueue.main.async {
                    self.isListening = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.lastError = error
                }
                continuation.finish()
            }
        }
    }

    /// Stops listening for speech input.
    @MainActor
    public func stopListening() {
        stopListeningInternal()
    }

    // MARK: - Private Methods

    private func stopListeningInternal() {
        isListening = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }

    private func setupAudioEngine() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    // MARK: - SFSpeechRecognizerDelegate

    nonisolated public func speechRecognizer(
        _ speechRecognizer: SFSpeechRecognizer,
        availabilityDidChange available: Bool
    ) {
        Task { @MainActor in
            self.isListening = available && self.isListening
        }
    }
}

/// Errors that can occur during speech recognition.
public enum SpeechError: LocalizedError {
    /// Microphone access was denied.
    case authorizationDenied

    /// Failed to set up audio engine.
    case audioSetupFailed

    /// Speech recognizer is not available.
    case recognitionUnavailable

    public var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Microphone access is required for voice input"
        case .audioSetupFailed:
            return "Failed to set up audio recording"
        case .recognitionUnavailable:
            return "Speech recognition is not available on this device"
        }
    }
}
