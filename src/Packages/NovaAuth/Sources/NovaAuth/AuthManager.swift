import Foundation
import Combine
import NovaCore

/// Manages authentication state and tokens for the Nova app.
///
/// Provides Sign in with Apple integration, token storage via Keychain,
/// and automatic token refresh. Conforms to TokenProvider protocol.
@MainActor
public class AuthManager: ObservableObject, TokenProvider {
    /// Current authentication state.
    @Published public var authState: AuthState = .unauthenticated

    /// Currently authenticated user.
    @Published public var currentUser: User?

    /// Whether the user is authenticated.
    @Published public var isAuthenticated: Bool = false

    /// Underlying API client for authentication requests.
    private let apiClient: APIClient

    /// Keychain helper for secure token storage.
    private let keychain = KeychainHelper()

    /// Keys for keychain storage.
    private enum KeychainKeys {
        static let accessToken = "nova.auth.accessToken"
        static let refreshToken = "nova.auth.refreshToken"
    }

    /// Initialize a new AuthManager.
    /// - Parameters:
    ///   - apiClient: The API client for authentication requests.
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    // MARK: - TokenProvider Conformance

    /// Gets the current access token, refreshing if necessary.
    public var accessToken: String? {
        get async {
            // Return cached token
            if let token = keychain.load(key: KeychainKeys.accessToken) {
                return String(data: token, encoding: .utf8)
            }
            return nil
        }
    }

    /// Gets the stored refresh token.
    public var refreshToken: String? {
        get async {
            if let token = keychain.load(key: KeychainKeys.refreshToken) {
                return String(data: token, encoding: .utf8)
            }
            return nil
        }
    }

    /// Updates the stored tokens.
    public func updateTokens(accessToken: String, refreshToken: String) async {
        if let accessData = accessToken.data(using: .utf8) {
            try? keychain.save(key: KeychainKeys.accessToken, data: accessData)
        }
        if let refreshData = refreshToken.data(using: .utf8) {
            try? keychain.save(key: KeychainKeys.refreshToken, data: refreshData)
        }
    }

    /// Clears the stored tokens (on logout).
    public func clearTokens() async {
        try? keychain.delete(key: KeychainKeys.accessToken)
        try? keychain.delete(key: KeychainKeys.refreshToken)
    }

    // MARK: - Authentication Methods

    /// Signs in with an Apple ID credential token.
    ///
    /// - Parameters:
    ///   - credential: The Apple ID credential (user ID token string).
    @MainActor
    public func signInWithApple(credential: String) async {
        authState = .authenticating

        do {
            let response: SignInResponse = try await apiClient.request(.signIn(appleToken: credential))

            // Store tokens
            await updateTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )

            // Update state
            currentUser = response.user
            isAuthenticated = true
            authState = .authenticated(response.user)
        } catch let error as APIError {
            authState = .error(error)
            isAuthenticated = false
        } catch {
            let error = APIError.custom(error.localizedDescription)
            authState = .error(error)
            isAuthenticated = false
        }
    }

    /// Refreshes the access token using the refresh token.
    @MainActor
    public func refreshToken() async throws {
        guard let refreshToken = await self.refreshToken else {
            throw APIError.unauthorized
        }

        let response: TokenResponse = try await apiClient.request(
            .refreshToken(refreshToken: refreshToken)
        )

        await updateTokens(accessToken: response.accessToken, refreshToken: refreshToken)
    }

    /// Signs out the current user, clearing all auth state.
    @MainActor
    public func signOut() async {
        await clearTokens()
        currentUser = nil
        isAuthenticated = false
        authState = .unauthenticated
    }

    /// Deletes the user account.
    @MainActor
    public func deleteAccount() async throws {
        let _: EmptyResponse = try await apiClient.request(.deleteAccount())
        await signOut()
    }

    /// Development-only bypass for testing without Apple Sign In.
    ///
    /// S14-VOX-02: hits `POST /auth/dev-bypass`, which mints a REAL
    /// token pair for the backend's deterministic dev user, and stores
    /// it via `updateTokens(...)` — every subsequent API call is then
    /// properly authenticated instead of riding whatever stale token
    /// the keychain happened to hold (the "stale keychain bites you"
    /// failure mode that cost 30 minutes of demo prep).
    ///
    /// If the backend is unreachable (offline UI work), falls back to
    /// the old local-only mock state — authenticated UI, no tokens.
    #if DEBUG
    @MainActor
    public func devBypassLogin() async {
        authState = .authenticating

        do {
            let response: DevBypassResponse = try await apiClient.request(.devBypass())

            await updateTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken
            )

            let user = User(
                id: response.user.id,
                appleId: "dev.tester",
                email: response.user.email,
                displayName: response.user.displayName,
                createdAt: Date()
            )
            currentUser = user
            isAuthenticated = true
            authState = .authenticated(user)
        } catch {
            // Backend not running — keep the legacy local-only bypass
            // so offline UI development still works. No tokens stored;
            // API calls will 401 until the backend is reachable.
            let mockUser = User(
                id: UUID(),
                appleId: "dev.tester",
                email: "dev-tester@nova.local",
                displayName: "Dev Tester",
                createdAt: Date()
            )
            currentUser = mockUser
            isAuthenticated = true
            authState = .authenticated(mockUser)
        }
    }
    #endif

    /// Checks if there's a cached session and restores it.
    @MainActor
    public func restoreSession() async {
        if await accessToken != nil {
            // Try to fetch the user profile to validate the token
            do {
                let user: User = try await apiClient.request(.getProfile())
                currentUser = user
                isAuthenticated = true
                authState = .authenticated(user)
            } catch {
                // Token is invalid, clear it
                await clearTokens()
                authState = .unauthenticated
            }
        }
    }
}

/// Authentication state enum.
public enum AuthState {
    /// User is not authenticated.
    case unauthenticated

    /// Authentication is in progress.
    case authenticating

    /// User is authenticated.
    case authenticated(User)

    /// An error occurred during authentication.
    case error(Error)
}

// MARK: - Response Models

/// Response from sign-in endpoint.
private struct SignInResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

/// Response from token refresh endpoint.
private struct TokenResponse: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

/// Empty response for endpoints that don't return data.
private struct EmptyResponse: Decodable {}

/// Response from the dev-bypass endpoint (S14-VOX-02). Keyed to the
/// backend's actual camelCase wire shape (which passes through the
/// `.convertFromSnakeCase` decoder unchanged); the user payload is
/// minimal — `{ id, displayName, email? }` — so it gets its own type
/// rather than forcing a full `User` decode that would fail on the
/// missing `createdAt`.
private struct DevBypassResponse: Decodable {
    struct DevUser: Decodable {
        let id: UUID
        let displayName: String
        let email: String?
    }

    let accessToken: String
    let refreshToken: String
    let user: DevUser
}
