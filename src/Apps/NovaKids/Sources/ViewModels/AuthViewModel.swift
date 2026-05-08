import Foundation
import SwiftUI
import NovaAuth
import NovaCore
import Combine

/// ViewModel for authentication screens, wrapping AuthManager for SwiftUI.
///
/// Provides:
/// - `signInWithApple()` method
/// - Published properties for UI binding
/// - Error state handling
@MainActor
public class AuthViewModel: ObservableObject {
    /// Reference to the AuthManager (injected).
    private let authManager: AuthManager

    /// Whether a sign-in is currently in progress.
    @Published public var isLoading = false

    /// Whether the user is authenticated.
    @Published public var isAuthenticated = false

    /// Currently authenticated user.
    @Published public var currentUser: User?

    /// Last error encountered.
    @Published public var error: AuthError?

    private var cancellables = Set<AnyCancellable>()

    private static let placeholderBaseURL: URL = {
        URL(string: "https://api.nova.local")
            ?? URL(string: "about:blank")
            ?? URL(fileURLWithPath: "/")
    }()

    /// Initialize the ViewModel with an AuthManager.
    ///
    /// - Parameters:
    ///   - authManager: The AuthManager instance to use (defaults to creating one).
    public init(authManager: AuthManager? = nil) {
        if let authManager = authManager {
            self.authManager = authManager
        } else {
            // Create a new AuthManager with default API client
            self.authManager = AuthManager(
                apiClient: APIClient(
                    baseURL: Self.placeholderBaseURL,
                    tokenProvider: _DefaultTokenProvider()
                )
            )
        }

        // Observe auth state from AuthManager
        self.authManager.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }
        .store(in: &cancellables)

        // Sync initial state
        self.isAuthenticated = self.authManager.isAuthenticated
        self.currentUser = self.authManager.currentUser
    }

    /// Signs in with Apple using the user identifier.
    ///
    /// - Parameters:
    ///   - userIdentifier: The Apple user ID from ASAuthorizationAppleIDCredential.user
    public func signInWithApple(userIdentifier: String) async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        await authManager.signInWithApple(credential: userIdentifier)

        // Update published state
        isAuthenticated = authManager.isAuthenticated
        currentUser = authManager.currentUser

        // Set error if auth failed
        if !isAuthenticated {
            error = .signInFailed
        }
    }

    /// Signs out the current user.
    public func signOut() async {
        await authManager.signOut()
        isAuthenticated = authManager.isAuthenticated
        currentUser = authManager.currentUser
    }
}

/// Authentication-related errors.
public enum AuthError: LocalizedError {
    case signInFailed
    case networkError
    case invalidCredentials
    case unknown

    public var errorDescription: String? {
        switch self {
        case .signInFailed:
            return "Sign in failed. Please try again."
        case .networkError:
            return "Network error. Please check your connection."
        case .invalidCredentials:
            return "Invalid credentials. Please try again."
        case .unknown:
            return "An unexpected error occurred."
        }
    }
}

// MARK: - Default Token Provider

private class _DefaultTokenProvider: TokenProvider {
    var accessToken: String? {
        get async { nil }
    }

    var refreshToken: String? {
        get async { nil }
    }

    func updateTokens(accessToken: String, refreshToken: String) async {}

    func clearTokens() async {}
}
