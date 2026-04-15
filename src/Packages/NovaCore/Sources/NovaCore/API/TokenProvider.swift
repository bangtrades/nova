import Foundation

/// Protocol for providing JWT tokens to the API client.
///
/// Implementations of this protocol handle token storage, refresh, and retrieval.
public protocol TokenProvider: AnyObject {
    /// Gets the current access token, refreshing if necessary.
    var accessToken: String? { get async }

    /// Gets the stored refresh token.
    var refreshToken: String? { get async }

    /// Updates the stored tokens.
    func updateTokens(accessToken: String, refreshToken: String) async

    /// Clears the stored tokens (on logout).
    func clearTokens() async
}
