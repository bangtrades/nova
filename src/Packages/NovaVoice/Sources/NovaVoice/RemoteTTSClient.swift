import Foundation

/// S13-06 — Client for the Nova backend TTS proxy.
///
/// **Why a backend proxy and not direct OpenAI:** the iOS NovaKids binary
/// must NOT carry an `OPENAI_API_KEY`. Embedding the key in a kid-facing
/// app is a leak vector — `strings` against the IPA, App Store IPA caches,
/// jailbreak inspection, etc. The backend's `POST /api/v1/voice/tts`
/// endpoint takes the same Bearer token a kid already uses for `/lessons`,
/// proxies to OpenAI, caches the resulting MP3, and returns it. iOS never
/// sees the OpenAI key.
///
/// **Why this still lives in NovaVoice:** the NovaVoice package's contract
/// is "give me text, give me audio" — the *transport* (direct API vs.
/// backend proxy) is an implementation detail. NovaVoice consumers
/// (`VoiceManager`) shouldn't care which side has the OpenAI key.
///
/// **Backwards compatibility note:** the pre-S13 type was the same name
/// pointing at api.openai.com. The constructor signature changed
/// (`baseURL` is now the backend root, `authToken` is the Nova bearer
/// token, not an OpenAI key). All call sites are inside this package and
/// `NovaKidsApp.init()`, so the migration is mechanical.
public final class RemoteTTSClient: @unchecked Sendable {
    /// Backend base URL — same root that `APIRouter` uses.
    /// Concretely something like `http://192.168.1.42:3000/api/v1` on
    /// LAN or `http://localhost:3000/api/v1` in simulator.
    public let baseURL: URL

    /// Bearer token resolver. Lazy-async so `AuthManager`'s token-refresh
    /// machinery propagates without requiring `RemoteTTSClient` to know
    /// about NovaAuth or NovaCore.TokenProvider — keeps the package graph
    /// clean (NovaVoice has no upstream Swift package deps).
    public typealias TokenResolver = @Sendable () async -> String?

    private let tokenResolver: TokenResolver

    /// URLSession for network requests.
    private let session: URLSession

    /// Initialize a backend-proxy TTS client.
    ///
    /// - Parameters:
    ///   - baseURL: Backend API root (must include `/api/v1` suffix).
    ///   - tokenResolver: Closure returning the current Nova bearer token.
    ///     Called on every request so `AuthManager.accessToken` refresh
    ///     propagates without client reconstruction. Pass
    ///     `{ await authManager.accessToken }`.
    ///   - session: URLSession (defaults to `.shared`).
    public init(
        baseURL: URL,
        tokenResolver: @escaping TokenResolver,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenResolver = tokenResolver
        self.session = session
    }

    /// Generates speech audio for the given text.
    ///
    /// Returns the raw MP3 bytes from the backend cache or a fresh
    /// OpenAI generation. Reports backend cache hit/miss + per-request
    /// latency via the response object so callers (Oracle Voice tab,
    /// telemetry) can observe.
    ///
    /// - Parameters:
    ///   - text: The text to convert to speech (max 4096 chars).
    ///   - voice: One of `nova` / `fable` / `onyx` / `shimmer`
    ///     (the four kid-facing voices). Defaults to `nova`.
    ///   - model: `tts-1` (default, low-latency) or `tts-1-hd` (higher
    ///     quality, ~2× the cost).
    /// - Returns: A `TTSResult` with audio bytes + observability metadata.
    /// - Throws: `TTSError` mirroring backend status codes.
    public func generateSpeech(
        text: String,
        voice: String = "nova",
        model: String = "tts-1"
    ) async throws -> TTSResult {
        // Backend proxy lives at /voice/tts under the same /api/v1 root.
        let endpoint = baseURL.appendingPathComponent("voice/tts")

        // Build request body — exact shape the backend Zod schema expects.
        struct RequestBody: Encodable {
            let text: String
            let voice: String
            let model: String
        }
        let body = RequestBody(text: text, voice: voice, model: model)
        let bodyData = try JSONEncoder().encode(body)

        // Resolve auth token at request time (token refresh transparent).
        let token = await tokenResolver()

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = bodyData
        // Modest timeout — kid waiting room for a single card narration is
        // unforgiving. tts-1 typically returns in 1–3s; 15s gives upstream
        // room and still bails before the kid taps the next card.
        request.timeoutInterval = 15

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TTSError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                // Pull observability headers — set by the backend proxy.
                let cacheHeader = httpResponse.value(forHTTPHeaderField: "X-Voice-Cache") ?? "?"
                let latencyHeader = httpResponse.value(forHTTPHeaderField: "X-Voice-Latency-Ms")
                let voiceUsed = httpResponse.value(forHTTPHeaderField: "X-Voice-Used") ?? voice
                let latencyMs = latencyHeader.flatMap { Int($0) } ?? 0
                return TTSResult(
                    audio: data,
                    voice: voiceUsed,
                    cacheHit: cacheHeader.uppercased() == "HIT",
                    latencyMs: latencyMs
                )

            case 401:
                throw TTSError.unauthorized

            case 400:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Invalid request"
                throw TTSError.invalidRequest(errorMessage)

            case 429:
                throw TTSError.rateLimited

            case 503:
                // Backend reports it has no OPENAI_API_KEY configured.
                throw TTSError.serverError(503)

            case 500...:
                throw TTSError.serverError(httpResponse.statusCode)

            default:
                throw TTSError.unexpectedStatusCode(httpResponse.statusCode)
            }
        } catch let error as TTSError {
            throw error
        } catch {
            throw TTSError.networkError(error)
        }
    }

    /// Available voice slugs — the four kid-facing personas Nova ships.
    /// Use `RemoteTTSClient.kidVoiceProfiles()` for richer display data.
    public static let availableVoices = ["nova", "fable", "onyx", "shimmer"]

    /// Available TTS models.
    public static let availableModels = ["tts-1", "tts-1-hd"]
}

/// Result of a successful TTS generation. Carries the raw MP3 plus
/// observability data (backend cache hit, generation latency) so the
/// Oracle Voice tab and runtime telemetry can show the picture.
public struct TTSResult: Sendable {
    public let audio: Data
    public let voice: String
    public let cacheHit: Bool
    public let latencyMs: Int

    public init(audio: Data, voice: String, cacheHit: Bool, latencyMs: Int) {
        self.audio = audio
        self.voice = voice
        self.cacheHit = cacheHit
        self.latencyMs = latencyMs
    }
}

/// Errors that can occur during TTS operations.
public enum TTSError: LocalizedError, Sendable {
    /// Unauthorized — invalid Nova bearer token (401 from backend).
    case unauthorized

    /// Invalid request parameters (400 from backend).
    case invalidRequest(String)

    /// Rate limited (429 from backend or upstream OpenAI).
    case rateLimited

    /// Backend-side server error.
    case serverError(Int)

    /// Unexpected HTTP status code.
    case unexpectedStatusCode(Int)

    /// Network error (timeout, no connectivity, etc.).
    case networkError(Error)

    /// Invalid response format (no HTTPURLResponse).
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Voice service authentication failed"
        case .invalidRequest(let message):
            return "Invalid voice request: \(message)"
        case .rateLimited:
            return "Voice service is busy — please try again in a moment"
        case .serverError(let statusCode):
            return "Voice service error (\(statusCode))"
        case .unexpectedStatusCode(let code):
            return "Unexpected voice response status: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid voice response format"
        }
    }
}
