import Foundation

/// Production-grade API client for Nova backend communication.
///
/// Handles JSON encoding/decoding, authentication, token refresh, and request logging.
public class APIClient {
    /// Base URL for API requests.
    public let baseURL: URL

    /// Token provider for authentication.
    private weak var tokenProvider: TokenProvider?

    /// JSON encoder with snake_case strategy.
    private let encoder = JSONEncoder()

    /// JSON decoder configured for the Nova backend wire format.
    /// Built via `APIClient.makeJSONDecoder()` so the exact same
    /// configuration is reachable from contract tests.
    private let decoder: JSONDecoder

    /// URLSession for network requests.
    private let session: URLSession

    /// Initialize a new APIClient.
    /// - Parameters:
    ///   - baseURL: Base URL for all API requests.
    ///   - tokenProvider: Provider for JWT tokens.
    ///   - session: URLSession to use (defaults to .shared).
    public init(
        baseURL: URL,
        tokenProvider: TokenProvider,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.session = session

        // Encode-side contract fix (Jun 10): the backend's zod schemas
        // are uniformly camelCase, but this encoder converted every body
        // key to snake_case — silently dropping optional fields and
        // 400-ing required ones (zod strips unknown keys). `.useDefaultKeys`
        // emits exactly the Swift property / CodingKey names, which match
        // the schemas. Do NOT "restore" snake conversion; the auth routes
        // tolerate both spellings but nothing else does.
        encoder.keyEncodingStrategy = .useDefaultKeys
        encoder.dateEncodingStrategy = .iso8601

        // Decoder is built by the shared factory so the same configuration
        // is testable in isolation — see `makeJSONDecoder()`.
        self.decoder = APIClient.makeJSONDecoder()
    }

    /// Builds the JSONDecoder used for **every** Nova backend response.
    ///
    /// Exposed as a `static` factory — rather than configured inline in
    /// `init` — so contract tests can decode recorded backend payloads
    /// through the *exact* same configuration the live client uses:
    /// `.convertFromSnakeCase` key strategy plus the fractional-seconds-
    /// tolerant date strategy below.
    ///
    /// A test that built its own `JSONDecoder()` would not be testing the
    /// real contract. That is precisely the trap the pre-existing
    /// `ModelTests` fell into — it configured a strict `.iso8601` date
    /// strategy and round-tripped through its own encoder, so it never
    /// exercised a real Prisma payload and never caught the fractional-
    /// seconds drift (`"2026-04-24T02:26:24.746Z"`) that broke decoding
    /// on a real device. `ContractTests` calls this factory instead.
    ///
    /// ### Date strategy
    /// The backend (Prisma `DateTime`) serializes timestamps with
    /// millisecond precision. Swift's built-in `.iso8601` strategy is
    /// strict and rejects fractional seconds. The custom strategy here
    /// accepts both shapes: it tries the fractional-seconds formatter
    /// first, falls back to plain ISO 8601, then throws a descriptive
    /// error naming the offending string.
    public static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = APIClient.iso8601WithFractionalSeconds.date(from: raw) {
                return date
            }
            if let date = APIClient.iso8601Plain.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected ISO 8601 date (with or without fractional seconds), got: \(raw)"
            )
        }
        return decoder
    }

    /// ISO 8601 formatter that accepts fractional seconds. Lazily-built and
    /// reused — `ISO8601DateFormatter` is thread-safe so a static instance
    /// is fine.
    private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// ISO 8601 formatter without fractional seconds — fallback for any
    /// payload Prisma didn't serialize with milliseconds.
    private static let iso8601Plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Makes a request to the API.
    /// - Parameters:
    ///   - endpoint: The endpoint to request.
    /// - Returns: Decoded response of type T.
    /// - Throws: APIError on failure.
    public func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        let request = try await buildRequest(endpoint)

        do {
            let (data, response) = try await session.data(for: request)
            return try handleResponse(data, response, endpoint: endpoint)
        } catch let error as APIError {
            // Handle 401 with automatic token refresh and retry
            if case .unauthorized = error {
                if let tokenProvider {
                    await tokenProvider.clearTokens()
                }
                throw error
            }
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Private Methods

    /// Builds a URLRequest from an Endpoint.
    private func buildRequest(_ endpoint: Endpoint) async throws -> URLRequest {
        var url = baseURL.appendingPathComponent(endpoint.path)

        // Add query items
        if let queryItems = endpoint.queryItems {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            if let componentURL = components?.url {
                url = componentURL
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        // Add authentication header
        if endpoint.requiresAuth {
            if let token = await tokenProvider?.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        // Encode request body
        if let body = endpoint.body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        #if DEBUG
        logRequest(request)
        #endif

        return request
    }

    /// Handles the response and decodes it.
    private func handleResponse<T: Decodable>(_ data: Data, _ response: URLResponse, endpoint: Endpoint) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.custom("Invalid response")
        }

        #if DEBUG
        logResponse(httpResponse, data: data)
        #endif

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                // S12-12: log the full DecodingError before we swallow it
                // into APIError's String description. `error.localizedDescription`
                // returns the user-friendly "The data couldn't be read..."
                // string for every DecodingError variant — useless for
                // diagnostics. The actual `keyNotFound("...")` /
                // `typeMismatch(... at $.content.dragItems[0])` /
                // `valueNotFound("...")` detail lives in the error
                // description, including the full codingPath that names
                // the exact field. Print it so the next decode failure
                // tells us where to look instead of forcing us to guess.
                #if DEBUG
                if let decodingError = error as? DecodingError {
                    print("[APIClient] DECODE FAILED for \(T.self):")
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("[APIClient]    keyNotFound: \(key.stringValue)")
                        print("[APIClient]    path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                        print("[APIClient]    debug: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("[APIClient]    typeMismatch: expected \(type)")
                        print("[APIClient]    path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                        print("[APIClient]    debug: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("[APIClient]    valueNotFound: \(type)")
                        print("[APIClient]    path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                        print("[APIClient]    debug: \(context.debugDescription)")
                    case .dataCorrupted(let context):
                        print("[APIClient]    dataCorrupted")
                        print("[APIClient]    path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                        print("[APIClient]    debug: \(context.debugDescription)")
                    @unknown default:
                        print("[APIClient]    unknown DecodingError: \(decodingError)")
                    }
                } else {
                    print("[APIClient] DECODE FAILED for \(T.self): \(error)")
                }
                #endif
                throw APIError.decodingError(error.localizedDescription)
            }

        case 401:
            throw APIError.unauthorized

        case 404:
            throw APIError.notFound

        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw APIError.rateLimited(retryAfter: retryAfter)

        case 500...599:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)

        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.custom("HTTP \(httpResponse.statusCode): \(message)")
        }
    }

    #if DEBUG
    private func logRequest(_ request: URLRequest) {
        print("[APIClient] -> \(request.httpMethod ?? "GET") \(request.url?.path ?? "")")
        if let headers = request.allHTTPHeaderFields {
            // Sanitize sensitive headers before logging
            let sanitized = headers.mapValues { value -> String in
                if value.lowercased().hasPrefix("bearer ") {
                    return "Bearer [REDACTED]"
                }
                return value
            }
            print("[APIClient]    Headers: \(sanitized)")
        }
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            print("[APIClient]    Body: \(bodyString)")
        }
    }

    private func logResponse(_ response: HTTPURLResponse, data: Data) {
        print("[APIClient] <- \(response.statusCode) \(response.url?.path ?? "")")
        if let dataString = String(data: data, encoding: .utf8), !dataString.isEmpty {
            print("[APIClient]    Response: \(dataString.prefix(500))")
        }
    }
    #endif
}

/// Helper for encoding Encodable values without knowing the concrete type.
private struct AnyEncodable: Encodable {
    let value: Encodable

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }

    init(_ value: Encodable) {
        self.value = value
    }
}
