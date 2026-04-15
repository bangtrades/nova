import Foundation

/// Errors that can occur during API operations.
public enum APIError: LocalizedError, Equatable {
    /// Unauthorized (401) - token invalid or expired.
    case unauthorized

    /// Not found (404) - resource doesn't exist.
    case notFound

    /// Server error (5xx).
    case serverError(statusCode: Int, message: String)

    /// Network error (no connectivity, timeout, etc.).
    case networkError(Error)

    /// JSON decoding error.
    case decodingError(String)

    /// Rate limited (429) - too many requests.
    case rateLimited(retryAfter: TimeInterval?)

    /// Custom error with message.
    case custom(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Unauthorized. Please sign in again."
        case .notFound:
            return "The requested resource was not found."
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "Rate limited. Retry after \(Int(retryAfter)) seconds."
            }
            return "Rate limited. Please try again later."
        case .custom(let message):
            return message
        }
    }

    public static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.unauthorized, .unauthorized):
            return true
        case (.notFound, .notFound):
            return true
        case let (.serverError(code1, msg1), .serverError(code2, msg2)):
            return code1 == code2 && msg1 == msg2
        case let (.decodingError(msg1), .decodingError(msg2)):
            return msg1 == msg2
        case let (.rateLimited(retry1), .rateLimited(retry2)):
            return retry1 == retry2
        case let (.custom(msg1), .custom(msg2)):
            return msg1 == msg2
        default:
            return false
        }
    }
}
