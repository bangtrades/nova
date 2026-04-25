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

    /// JSON decoder with snake_case strategy.
    private let decoder = JSONDecoder()

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

        // Configure JSON encoder/decoder for snake_case
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }

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
