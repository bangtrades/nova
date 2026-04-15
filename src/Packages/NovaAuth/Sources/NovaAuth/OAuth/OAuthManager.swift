import Foundation
import Combine
import AuthenticationServices
import CryptoKit
import NovaCore

/// Manages OAuth connections to external LLM providers.
///
/// Handles the OAuth flow for connecting services like OpenAI, and maintains
/// the list of connected providers.
@MainActor
public class OAuthManager: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    /// List of connected providers.
    @Published public var connectedProviders: [LLMProvider] = []

    /// Whether a connection operation is in progress.
    @Published public var isConnecting: Bool = false

    /// Last error from provider operations.
    @Published public var lastError: Error?

    /// The API router for making requests.
    private let apiRouter: APIRouting

    /// Current web authentication session.
    private var webAuthSession: ASWebAuthenticationSession?

    /// Initialize a new OAuthManager.
    /// - Parameters:
    ///   - apiRouter: The API router for making requests.
    public init(apiRouter: APIRouting) {
        self.apiRouter = apiRouter
    }

    // MARK: - OAuth Operations

    /// Connects a new LLM provider via OAuth.
    ///
    /// Opens a system WebAuthenticationSession to perform the OAuth flow.
    ///
    /// - Parameters:
    ///   - provider: The type of provider to connect.
    public func connect(provider: LLMProvider.LLMProviderType) async throws {
        isConnecting = true
        lastError = nil

        defer { isConnecting = false }

        do {
            let config = OpenAIOAuthConfig.defaultConfig

            // Generate PKCE parameters
            let codeVerifier = generateCodeVerifier()
            let codeChallenge = generateCodeChallenge(from: codeVerifier)

            // Build authorization URL
            var components = URLComponents(url: config.authorizationURL, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: config.clientId),
                URLQueryItem(name: "redirect_uri", value: config.redirectURI.absoluteString),
                URLQueryItem(name: "response_type", value: "code"),
                URLQueryItem(name: "scope", value: config.scopes.joined(separator: " ")),
                URLQueryItem(name: "code_challenge", value: codeChallenge),
                URLQueryItem(name: "code_challenge_method", value: "S256"),
            ]

            let authorizationURL = components.url!

            // Perform web authentication
            // Store session reference BEFORE entering continuation to avoid
            // mutating self inside the continuation closure (Sendable safety).
            let authorizationCode: String = try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(
                    url: authorizationURL,
                    callbackURLScheme: config.redirectURI.scheme
                ) { callbackURL, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let callbackURL = callbackURL else {
                        continuation.resume(
                            throwing: OAuthError.invalidCallbackURL
                        )
                        return
                    }

                    guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                          let code = components.queryItems?.first(where: { $0.name == "code" })?.value
                    else {
                        continuation.resume(
                            throwing: OAuthError.missingAuthorizationCode
                        )
                        return
                    }

                    continuation.resume(returning: code)
                }

                // Set up session before starting — no mutation inside continuation
                session.presentationContextProvider = self
                self.webAuthSession = session

                if !session.start() {
                    continuation.resume(throwing: OAuthError.sessionStartFailed)
                }
            }

            // Exchange code for tokens at the backend
            let _: EmptyResponse = try await apiRouter.request(
                .connectProvider(code: authorizationCode, provider: provider)
            )

            // Refresh the provider list
            try await refreshProviders()
        } catch {
            lastError = error
            throw error
        }
    }

    /// Disconnects a provider.
    ///
    /// - Parameters:
    ///   - providerId: The ID of the provider to disconnect.
    public func disconnect(providerId: UUID) async throws {
        isConnecting = true
        lastError = nil

        defer { isConnecting = false }

        do {
            let _: EmptyResponse = try await apiRouter.request(
                .disconnectProvider(id: providerId)
            )

            try await refreshProviders()
        } catch {
            lastError = error
            throw error
        }
    }

    /// Fetches the current list of connected providers.
    public func refreshProviders() async throws {
        do {
            let providers: [LLMProvider] = try await apiRouter.request(.getProviders())
            connectedProviders = providers
        } catch {
            lastError = error
            throw error
        }
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the main window of the app
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene
        return windowScene?.windows.first ?? ASPresentationAnchor()
    }

    // MARK: - Private Helpers

    private func generateCodeVerifier() -> String {
        // PKCE code verifier: random 43-128 character string
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)

        return Data(buffer)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }

    private func generateCodeChallenge(from codeVerifier: String) -> String {
        guard let data = codeVerifier.data(using: .utf8) else {
            return codeVerifier
        }

        let hash = SHA256.hash(data: data)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }
}

/// Errors that can occur during OAuth operations.
public enum OAuthError: LocalizedError {
    /// The callback URL from authentication was invalid.
    case invalidCallbackURL

    /// The authorization code was missing from the callback.
    case missingAuthorizationCode

    /// Failed to start the authentication session.
    case sessionStartFailed

    /// User cancelled the authentication.
    case userCancelled

    public var errorDescription: String? {
        switch self {
        case .invalidCallbackURL:
            return "Invalid callback URL received from authentication provider"
        case .missingAuthorizationCode:
            return "Authorization code missing from callback"
        case .sessionStartFailed:
            return "Failed to start authentication session"
        case .userCancelled:
            return "User cancelled authentication"
        }
    }
}

/// Empty response for endpoints that don't return data.
private struct EmptyResponse: Decodable {}

