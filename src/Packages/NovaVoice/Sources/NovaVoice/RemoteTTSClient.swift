import Foundation

/// Client for OpenAI's Text-to-Speech API.
///
/// Generates high-quality speech audio from text using remote OpenAI models.
/// Supports different voices and models.
public class RemoteTTSClient {
    /// Base URL for the API (defaults to OpenAI's API).
    public let baseURL: URL

    /// API authentication token.
    private let authToken: String

    /// URLSession for network requests.
    private let session: URLSession

    /// Initialize a new RemoteTTSClient.
    /// - Parameters:
    ///   - authToken: OpenAI API key.
    ///   - baseURL: Base URL for the API (defaults to OpenAI).
    ///   - session: URLSession to use (defaults to .shared).
    public init(
        authToken: String,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        session: URLSession = .shared
    ) {
        self.authToken = authToken
        self.baseURL = baseURL
        self.session = session
    }

    /// Generates speech audio from text.
    ///
    /// - Parameters:
    ///   - text: The text to convert to speech.
    ///   - voice: The voice to use (alloy, echo, fable, onyx, nova, shimmer).
    ///   - model: The TTS model (tts-1 for low latency, tts-1-hd for high quality).
    /// - Returns: Audio data in MP3 format.
    /// - Throws: TTSError on failure.
    public func generateSpeech(
        text: String,
        voice: String = "nova",
        model: String = "tts-1"
    ) async throws -> Data {
        let endpoint = baseURL.appendingPathComponent("/audio/speech")

        // Build request body
        struct RequestBody: Encodable {
            let model: String
            let input: String
            let voice: String
        }

        let body = RequestBody(model: model, input: text, voice: voice)
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(body)

        // Create request
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        // Make request
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TTSError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                return data

            case 401:
                throw TTSError.unauthorized

            case 400:
                let errorMessage = String(data: data, encoding: .utf8) ?? "Invalid request"
                throw TTSError.invalidRequest(errorMessage)

            case 429:
                throw TTSError.rateLimited

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

    /// Available voices for TTS.
    public static let availableVoices = ["alloy", "echo", "fable", "onyx", "nova", "shimmer"]

    /// Available TTS models.
    public static let availableModels = ["tts-1", "tts-1-hd"]
}

/// Errors that can occur during TTS operations.
public enum TTSError: LocalizedError {
    /// Unauthorized - invalid API key.
    case unauthorized

    /// Invalid request parameters.
    case invalidRequest(String)

    /// Rate limited - too many requests.
    case rateLimited

    /// Server error.
    case serverError(Int)

    /// Unexpected HTTP status code.
    case unexpectedStatusCode(Int)

    /// Network error.
    case networkError(Error)

    /// Invalid response format.
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Invalid OpenAI API key"
        case .invalidRequest(let message):
            return "Invalid TTS request: \(message)"
        case .rateLimited:
            return "OpenAI API rate limit exceeded"
        case .serverError(let statusCode):
            return "OpenAI server error (\(statusCode))"
        case .unexpectedStatusCode(let code):
            return "Unexpected response status: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response format"
        }
    }
}
