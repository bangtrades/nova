import Foundation
import AVFoundation

/// S13-06 — Central voice manager. Routes every spoken line through the
/// backend OpenAI TTS proxy by default; falls back to local AVSpeech only
/// when remote is unreachable or unconfigured.
///
/// Why the default flipped (S12 → S13): kids who can't read fluently
/// rely on the voice. Apple's AVSpeech sounds like a robot. OpenAI's
/// `nova` voice sounds like a real human storyteller for ~$0.015 per
/// 1k chars — at touch-test scale this is rounding error. The voice IS
/// the primary UX channel; treating premium TTS as opt-in was wrong.
///
/// Design contract:
///   - Caller hands in **text** (and optionally a voice override).
///   - VoiceManager picks: cached MP3 → backend MP3 → AVSpeech (in that order).
///   - Caller never sees which path won; observability is published via
///     `lastResult` so Oracle / telemetry can report cache-hit-rate + p95
///     latency.
@MainActor
public final class VoiceManager: NSObject, ObservableObject {
    /// Whether speech is currently playing.
    @Published public var isSpeaking: Bool = false

    /// Voice the kid (or persona-aware suggestion) has currently selected.
    /// Defaults to `nova`. Mutated by `VoicePickerView` via
    /// `setVoice(_:)`. Persisted independently in `VoicePreferenceStore`.
    @Published public var currentVoice: String = "nova"

    /// Most recent result — published so Oracle Voice tab + telemetry
    /// surfaces can read cache hit / latency without sniffing requests.
    /// `nil` until the first remote call lands. Set on the main actor.
    @Published public var lastResult: TTSResult? = nil

    /// Local speech synthesizer for free TTS — used as fallback when remote
    /// fails or is unconfigured.
    private let speechSynthesizer: SpeechSynthesizer

    /// Backend TTS proxy client. May be nil in test contexts; in production
    /// `NovaKidsApp.init()` always builds one.
    private let remoteTTSClient: RemoteTTSClient?

    /// AVAudioPlayer for remote audio playback. Held so we can stop/pause.
    private var audioPlayer: AVAudioPlayer?

    /// In-memory cache for already-fetched audio. Mirrors the backend cache
    /// but with the iOS process as the L1 (zero-network playback for
    /// repeated lines, e.g. picker samples).
    private var audioCache: [String: Data] = [:]

    /// Maximum cache size (number of clips). Each clip is ~30–80KB.
    /// 50 entries × 80KB ≈ 4MB ceiling — well within iPad RAM budget.
    private let maxCacheSize: Int = 50

    /// Track outstanding playback start so we can ignore stale finishes.
    private var currentPlaybackId = UUID()

    /// Initialize a new VoiceManager.
    ///
    /// - Parameters:
    ///   - speechSynthesizer: Local AVSpeech synthesizer instance — used as
    ///     fallback when the backend proxy is unreachable.
    ///   - remoteTTSClient: Backend TTS proxy client. Production should
    ///     always pass a non-nil instance; nil only for unit tests.
    public init(
        speechSynthesizer: SpeechSynthesizer,
        remoteTTSClient: RemoteTTSClient? = nil
    ) {
        self.speechSynthesizer = speechSynthesizer
        self.remoteTTSClient = remoteTTSClient
        super.init()
    }

    /// Speak the given text. Defaults to remote TTS when available.
    ///
    /// - Parameters:
    ///   - text: Line to speak.
    ///   - voice: Override the kid's selected voice for this single line
    ///     (e.g. Dashy always uses `shimmer`). `nil` = use `currentVoice`.
    ///   - preferLocal: Force AVSpeech for this line (offline fallback test
    ///     / accessibility setting). Defaults to `false`.
    public func speak(
        text: String,
        voice: String? = nil,
        preferLocal: Bool = false
    ) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Local-only path — for offline fallback or accessibility opt-out.
        if preferLocal || remoteTTSClient == nil {
            try await speakLocal(trimmed)
            return
        }

        // Remote path with graceful AVSpeech fallback on any failure.
        let resolvedVoice = voice ?? currentVoice
        do {
            try await speakRemote(text: trimmed, voice: resolvedVoice)
        } catch {
            // Network glitch / rate limit / 503 → AVSpeech keeps the kid
            // moving rather than silent. Log via observability later.
            print("[VoiceManager] Remote TTS failed (\(error.localizedDescription)) — falling back to local AVSpeech")
            try await speakLocal(trimmed)
        }
    }

    /// Backwards-compat shim for pre-S13 call sites that used the old
    /// `preferRemote: Bool` parameter. Delegates to the new `speak`.
    /// Marked deprecated so the eventual cleanup pass finds it.
    @available(*, deprecated, message: "Use speak(text:voice:preferLocal:) — remote is now default")
    public func speak(text: String, preferRemote: Bool) async throws {
        try await speak(text: text, voice: nil, preferLocal: !preferRemote)
    }

    /// Stops the current speech immediately.
    public func stop() {
        speechSynthesizer.stop()
        audioPlayer?.stop()
        audioPlayer = nil
        isSpeaking = false
    }

    /// Pauses the current speech.
    public func pause() {
        speechSynthesizer.pause()
        audioPlayer?.pause()
    }

    /// Resumes paused speech.
    public func `continue`() {
        speechSynthesizer.continue()
        audioPlayer?.play()
    }

    /// Set the kid-selected voice. Persistence is the caller's job (the
    /// `VoicePreferenceStore` writes to UserDefaults). VoiceManager just
    /// holds the live value so the next `speak()` picks it up.
    public func setVoice(_ voice: String) {
        // Allow-list mirrors RemoteTTSClient.availableVoices.
        guard RemoteTTSClient.availableVoices.contains(voice) else { return }
        self.currentVoice = voice
    }

    /// Pre-fetch audio for a list of (text, voice) pairs. Useful at
    /// lesson-load time so card narration plays from cache instantly when
    /// the kid taps the speaker icon. Concurrency-bounded to 4 to avoid
    /// hammering the backend.
    public func preload(lines: [(text: String, voice: String)]) async {
        guard let client = remoteTTSClient else { return }
        // Process in chunks of 4 — bounded concurrency keeps the backend
        // proxy honest and respects OpenAI's TPM limits.
        for chunk in lines.chunked(into: 4) {
            await withTaskGroup(of: Void.self) { group in
                for line in chunk {
                    let cacheKey = "\(line.voice)|\(line.text)"
                    if audioCache[cacheKey] != nil { continue }
                    group.addTask { [weak self] in
                        let result = try? await client.generateSpeech(
                            text: line.text,
                            voice: line.voice
                        )
                        if let result {
                            await self?.cacheAudio(cacheKey, result.audio)
                        }
                    }
                }
            }
        }
    }

    /// Drop the in-memory iOS cache. Backend cache is unaffected. Useful
    /// when the kid switches voice persona — old voice's clips become
    /// dead weight.
    public func clearCache() {
        audioCache.removeAll()
    }

    // MARK: - Private

    /// Speak via local AVSpeech.
    private func speakLocal(_ text: String) async throws {
        await speechSynthesizer.speak(
            text,
            voice: .narrator,
            rate: 0.45
        )
        isSpeaking = speechSynthesizer.isSpeaking
    }

    /// Speak via the backend TTS proxy. Uses the iOS-side cache as L1.
    private func speakRemote(text: String, voice: String) async throws {
        guard let client = remoteTTSClient else {
            throw VoiceManagerError.remoteTTSUnavailable
        }

        let cacheKey = "\(voice)|\(text)"

        // L1 hit — skip the network entirely.
        if let cachedAudio = audioCache[cacheKey] {
            // Synthesize a "result" so observability surfaces still see it.
            self.lastResult = TTSResult(
                audio: cachedAudio,
                voice: voice,
                cacheHit: true,
                latencyMs: 0
            )
            try playAudio(cachedAudio)
            return
        }

        // Network — backend proxy handles its own L2 cache + OpenAI call.
        let result = try await client.generateSpeech(
            text: text,
            voice: voice,
            model: "tts-1"
        )

        cacheAudio(cacheKey, result.audio)
        self.lastResult = result
        try playAudio(result.audio)
    }

    /// Play raw MP3 bytes via AVAudioPlayer. AVAudioPlayer init throws on
    /// malformed data; caller wraps the throw and falls back to AVSpeech.
    private func playAudio(_ data: Data) throws {
        let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.mp3.rawValue)
        player.delegate = self
        player.prepareToPlay()
        player.play()
        audioPlayer = player
        isSpeaking = true
        currentPlaybackId = UUID()
    }

    /// Insert into the iOS audio cache with LRU eviction.
    private func cacheAudio(_ key: String, _ data: Data) {
        if audioCache.count >= maxCacheSize {
            if let oldestKey = audioCache.keys.first {
                audioCache.removeValue(forKey: oldestKey)
            }
        }
        audioCache[key] = data
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

// MARK: - Errors

public enum VoiceManagerError: LocalizedError {
    /// Remote TTS client is not configured (test/init path only).
    case remoteTTSUnavailable

    /// Failed to play audio.
    case audioPlaybackFailed(Error)

    /// Text is empty.
    case emptyText

    public var errorDescription: String? {
        switch self {
        case .remoteTTSUnavailable:
            return "Voice service is not available"
        case .audioPlaybackFailed(let error):
            return "Audio playback failed: \(error.localizedDescription)"
        case .emptyText:
            return "Cannot speak empty text"
        }
    }
}

// MARK: - Array chunking helper

extension Array {
    fileprivate func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
