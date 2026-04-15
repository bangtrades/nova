import Foundation
import NovaCore
import NovaAuth

#if DEBUG

/// Mock API client for previews.
extension APIClient {
    static func mock() -> APIClient {
        APIClient(
            baseURL: URL(string: "https://api.nova.local")!,
            tokenProvider: MockTokenProvider()
        )
    }
}

/// Mock token provider for previews.
class MockTokenProvider: TokenProvider {
    var accessToken: String? {
        get async { "mock_token" }
    }

    var refreshToken: String? {
        get async { "mock_refresh_token" }
    }

    func updateTokens(accessToken: String, refreshToken: String) async {}

    func clearTokens() async {}
}

#endif
