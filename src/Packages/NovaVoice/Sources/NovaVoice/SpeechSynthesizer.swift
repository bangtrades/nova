import Foundation
import AVFoundation

/// Synthesizes text to speech with kid-friendly voices.
///
/// Wraps AVSpeechSynthesizer to provide voice narration for learning content.
/// Supports different voice styles (Dashy, Narrator, Celebration).
public class SpeechSynthesizer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    /// Currently playing speech utterance.
    @Published public var isSpeaking: Bool = false

    /// Speech synthesizer instance.
    private let synthesizer = AVSpeechSynthesizer()

    /// Continuation for the active utterance. `speak` now awaits finish
    /// or cancellation so lesson-level read controls can show accurate
    /// "Reading" state instead of flipping back to idle immediately.
    private var speechContinuation: CheckedContinuation<Void, Never>?

    /// Active utterance identity. AVSpeech delegate callbacks can arrive
    /// after a new utterance starts, so only the active utterance is
    /// allowed to complete the continuation.
    private var activeUtterance: AVSpeechUtterance?

    /// Voice style for the synthesizer.
    public enum VoiceStyle {
        case dashy      // Kid-friendly, energetic
        case narrator    // Calm, clear adult voice
        case celebration // Excited, upbeat

        /// Get AVSpeechSynthesisVoice for this style.
        func getVoice() -> AVSpeechSynthesisVoice? {
            switch self {
            case .dashy:
                // Prefer female voice for Dashy
                return AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice()

            case .narrator:
                // Prefer male voice for Narrator
                return AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Daniel-compact") ??
                       AVSpeechSynthesisVoice(language: "en-US")

            case .celebration:
                // Use female voice for celebration
                return AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice()
            }
        }

        /// Get speech rate for this style.
        func getSpeechRate() -> Float {
            switch self {
            case .dashy:
                return 0.45 // Slightly slower for clarity
            case .narrator:
                return 0.40 // Deliberate pace
            case .celebration:
                return 0.50 // Slightly faster, more energetic
            }
        }

        /// Get pitch multiplier for this style.
        func getPitchMultiplier() -> Float {
            switch self {
            case .dashy:
                return 1.2 // Higher pitch for Dashy
            case .narrator:
                return 1.0 // Normal pitch
            case .celebration:
                return 1.3 // Even higher for excitement
            }
        }
    }

    /// Initialize a new SpeechSynthesizer.
    public override init() {
        super.init()
        synthesizer.delegate = self

        // Request audio session category for playback
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            options: .duckOthers
        )
    }

    /// Speaks text with the specified voice style and rate.
    ///
    /// - Parameters:
    ///   - text: The text to speak.
    ///   - voice: The voice style to use.
    ///   - rate: Speech rate (0.0 = slowest, 1.0 = normal, 2.0 = fastest).
    @MainActor
    public func speak(_ text: String, voice: VoiceStyle = .narrator, rate: Float = 0.45) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Stop any current speech
        speechContinuation?.resume()
        speechContinuation = nil
        activeUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = voice.getVoice()
        utterance.rate = rate
        utterance.pitchMultiplier = voice.getPitchMultiplier()

        // Add slight pause between sentences
        utterance.postUtteranceDelay = 0.1

        activeUtterance = utterance
        isSpeaking = true

        await withCheckedContinuation { continuation in
            speechContinuation = continuation
            synthesizer.speak(utterance)
        }
    }

    /// Stops the current speech immediately.
    @MainActor
    public func stop() {
        speechContinuation?.resume()
        speechContinuation = nil
        activeUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    /// Pauses the current speech.
    @MainActor
    public func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    /// Continues the paused speech.
    @MainActor
    public func `continue`() {
        synthesizer.continueSpeaking()
    }

    // MARK: - AVSpeechSynthesizerDelegate

    public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        DispatchQueue.main.async {
            guard utterance === self.activeUtterance else { return }
            self.isSpeaking = true
        }
    }

    public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        DispatchQueue.main.async {
            guard utterance === self.activeUtterance else { return }
            self.isSpeaking = false
            self.activeUtterance = nil
            self.speechContinuation?.resume()
            self.speechContinuation = nil
        }
    }

    public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        DispatchQueue.main.async {
            guard utterance === self.activeUtterance else { return }
            self.isSpeaking = false
            self.activeUtterance = nil
            self.speechContinuation?.resume()
            self.speechContinuation = nil
        }
    }
}
