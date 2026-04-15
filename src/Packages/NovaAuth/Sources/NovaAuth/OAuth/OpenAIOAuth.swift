import Foundation

/// OpenAI-specific OAuth configuration.
///
/// Contains the client ID, endpoints, and other settings needed to
/// perform the OAuth flow with OpenAI.
public struct OpenAIOAuthConfig {
    /// OAuth client ID for Nova with OpenAI.
    public let clientId: String

    /// Redirect URI for OAuth callback.
    public let redirectURI: URL

    /// OpenAI authorization endpoint.
    public let authorizationURL: URL

    /// OpenAI token endpoint.
    public let tokenURL: URL

    /// OAuth scopes to request.
    public let scopes: [String]

    /// Initialize a new OpenAIOAuthConfig.
    /// - Parameters:
    ///   - clientId: The OAuth client ID.
    ///   - redirectURI: The redirect URI for callbacks.
    ///   - authorizationURL: The OAuth authorization endpoint.
    ///   - tokenURL: The token exchange endpoint.
    ///   - scopes: Requested OAuth scopes.
    public init(
        clientId: String,
        redirectURI: URL,
        authorizationURL: URL,
        tokenURL: URL,
        scopes: [String]
    ) {
        self.clientId = clientId
        self.redirectURI = redirectURI
        self.authorizationURL = authorizationURL
        self.tokenURL = tokenURL
        self.scopes = scopes
    }

    /// Default configuration for OpenAI OAuth.
    ///
    /// Uses the standard OpenAI OAuth endpoints and Nova's registered
    /// client ID. The redirect URI uses the nova:// custom scheme.
    public static var defaultConfig: OpenAIOAuthConfig {
        let clientId = ProcessInfo.processInfo.environment["OPENAI_CLIENT_ID"]
            ?? Bundle.main.infoDictionary?["OPENAI_CLIENT_ID"] as? String
            ?? "not-configured"  // Safe fallback — OAuth will fail gracefully at request time

        #if DEBUG
        if clientId == "not-configured" {
            print("⚠️ [OpenAIOAuth] OPENAI_CLIENT_ID not set — OAuth will not work. Set in .xcconfig or environment.")
        }
        #endif

        return OpenAIOAuthConfig(
            clientId: clientId,
            redirectURI: URL(string: "nova://oauth-callback")!,
            authorizationURL: URL(string: "https://auth.openai.com/authorize")!,
            tokenURL: URL(string: "https://auth.openai.com/token")!,
            scopes: [
                "openid",
                "email",
                "profile",
                "https://api.openai.com/auth/realtime.modify",
            ]
        )
    }

    /// Configuration for OpenAI's development/testing environment.
    public static var stagingConfig: OpenAIOAuthConfig {
        let clientId = ProcessInfo.processInfo.environment["OPENAI_STAGING_CLIENT_ID"]
            ?? Bundle.main.infoDictionary?["OPENAI_STAGING_CLIENT_ID"] as? String
            ?? "staging-placeholder"
        return OpenAIOAuthConfig(
            clientId: clientId,
            redirectURI: URL(string: "nova-dev://oauth-callback")!,
            authorizationURL: URL(string: "https://staging-auth.openai.com/authorize")!,
            tokenURL: URL(string: "https://staging-auth.openai.com/token")!,
            scopes: [
                "openid",
                "email",
                "profile",
            ]
        )
    }
}
