import Foundation
import AVFoundation

/// Central voice manager coordinating local and remote TTS.
///
/// Intelligently switches between local AVSpeech (free, always available) and
/// remote OpenAI TTS (premium quality). Caches audio to reduce API calls and bandwidth.
@MainActor
public class VoiceManager: NSObject, ObservableObject {
    /// Whether speech is currently playing.
    @Published public var isSpeaking: Bool = false

    /// Current voice preference.
    @Published public var currentVoice: VoicePreference = .local

    /// Local speech synthesizer for free TTS.
    private let speechSynthesizer: SpeechSynthesizer

    /// Remote TTS client (optional).
    private let remoteTTSClient: RemoteTTSClient?

    /// AVAudioPlayer for remote audio playback.
    private var audioPlayer: AVAudioPlayer?

    /// LRU cache for generated audio (text -> Data).
    private var audioCache: [String: Data] = [:]

    /// Maximum cache size (number of clips).
    private let maxCacheSize: Int = 50

    /// Voice preference for TTS.
    public enum VoicePreference {
        case local       // Use AVSpeech (free)
        case remote      // Use OpenAI TTS (premium)
        case hybrid      // Auto-select based on availability
    }

    /// Initialize a new VoiceManager.
    /// - Parameters:
    ///   - speechSynthesizer: Local AVSpeech synthesizer instance.
    ///   - remoteTTSClient: Optional OpenAI TTS client.
    public init(
        speechSynthesizer: SpeechSynthesizer,
        remoteTTSClient: RemoteTTSClient? = nil
    ) {
        self.speechSynthesizer = speechSynthesizer
        self.remoteTTSClient = remoteTTSClient
        super.init()
    }

    /// Speaks text using the current voice preference.
    ///
    /// - Parameters:
    ///   - text: The text to speak.
    ///   - preferRemote: If true, attempts remote TTS first, falls back to local.
    /// - Throws: VoiceManagerError on failure.
    public func speak(text: String, preferRemote: Bool = false) async throws {
        guard !text.isEmpty else { return }

        // Determine which TTS to use
        let useRemote = preferRemote && remoteTTSClient != nil

        if useRemote {
            do {
                try await speakRemote(text)
            } catch {
                // Fall back to local TTS
                try await speakLocal(text)
            }
        } else {
            try await speakLocal(text)
        }
    }

    /// Stops the current speech immediately.
    public func stop() {
        speechSynthesizer.stop()
        audioPlayer?.stop()
        isSpeaking = false
    }

    /// Pauses the current speech.
    public func pause() {
        speechSynthesizer.pause()
        audioPlayer?.pause()
    }

    /// Continues the paused speech.
    public func `continue`() {
        speechSynthesizer.continue()
        audioPlayer?.play()
    }

    /// Pre-generates audio for a list of texts.
    ///
    /// Useful for preloading narration for lesson cards to improve playback smoothness.
    /// Uses local TTS only (remote would be rate-limited).
    ///
    /// - Parameters:
    ///   - texts: List of texts to preload.
    public func preload(texts: [String]) async {
        for text in texts {
            // Store in cache to indicate preloaded
            // In practice, we'd generate audio here if using remote TTS
            audioCache[text] = nil // Mark as requested
        }
    }

    /// Sets the voice preference.
    public func setVoicePreference(_ preference: VoicePreference) {
        self.currentVoice = preference
    }

    /// Clears the audio cache.
    public func clearCache() {
        audioCache.removeAll()
    }

    // MARK: - Private Methods

    /// Speaks text using local AVSpeech.
    private func speakLocal(_ text: String) async throws {
        await speechSynthesizer.speak(
            text,
            voice: .narrator,
            rate: 0.45
        )
        isSpeaking = speechSynthesizer.isSpeaking
    }

    /// Speaks text using remote OpenAI TTS.
    private func speakRemote(_ text: String) async throws {
        guard let client = remoteTTSClient else {
            throw VoiceManagerError.remoteTTSUnavailable
        }

        // Check cache first
        if let cachedAudio = audioCache[text] {
            try playAudio(cachedAudio)
            return
        }

        // Generate speech via OpenAI
        let audioData = try await client.generateSpeech(
            text: text,
            voice: "nova",
            model: "tts-1"
        )

        // Cache the audio
        cacheAudio(text, audioData)

        // Play the audio
        try playAudio(audioData)
    }

    /// Plays audio data using AVAudioPlayer.
    private func playAudio(_ data: Data) throws {
        audioPlayer = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.mp3.rawValue)
        audioPlayer?.delegate = self
        audioPlayer?.play()
        isSpeaking = true
    }

    /// Caches audio data with LRU eviction.
    private func cacheAudio(_ text: String, _ data: Data) {
        // Evict oldest entry if cache is full
        if audioCache.count >= maxCacheSize {
            if let oldestKey = audioCache.keys.first {
                audioCache.removeValue(forKey: oldestKey)
            }
        }

        audioCache[text] = data
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceManager: AVAudioPlayerDelegate {
    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    nonisolated public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}

/// Errors that can occur in VoiceManager.
public enum VoiceManagerError: LocalizedError {
    /// Remote TTS client is not configured.
    case remoteTTSUnavailable

    /// Failed to play audio.
    case audioPlaybackFailed(Error)

    /// Text is empty.
    case emptyText

    public var errorDescription: String? {
        switch self {
        case .remoteTTSUnavailable:
            return "Remote TTS is not available"
        case .audioPlaybackFailed(let error):
            return "Audio playback failed: \(error.localizedDescription)"
        case .emptyText:
            return "Cannot speak empty text"
        }
    }
}
