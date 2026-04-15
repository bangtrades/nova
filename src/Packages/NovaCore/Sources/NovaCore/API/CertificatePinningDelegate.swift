import Foundation
import CryptoKit

/// URLSession delegate that implements SPKI (Subject Public Key Info) certificate pinning.
///
/// Validates that the server's certificate matches one of the pre-configured public key hashes.
/// This prevents man-in-the-middle attacks even if a rogue CA issues a fraudulent certificate.
///
/// Usage:
/// ```swift
/// let delegate = CertificatePinningDelegate(pinnedHashes: [
///     "base64-encoded-sha256-of-spki"
/// ])
/// let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
/// ```
public final class CertificatePinningDelegate: NSObject, URLSessionDelegate, Sendable {
    /// SHA-256 hashes of the Subject Public Key Info (SPKI) to pin against.
    /// Base64-encoded. Generate with:
    /// `openssl s_client -connect api.nova.app:443 | openssl x509 -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256 -binary | base64`
    private let pinnedHashes: Set<String>

    /// Domains to apply pinning to. Empty means pin all domains.
    private let pinnedDomains: Set<String>

    /// Initialize with pinned SPKI hashes.
    /// - Parameters:
    ///   - pinnedHashes: Base64-encoded SHA-256 hashes of server SPKI.
    ///   - pinnedDomains: Domains to pin (empty = pin all). e.g. ["api.nova.app"]
    public init(pinnedHashes: [String], pinnedDomains: [String] = []) {
        self.pinnedHashes = Set(pinnedHashes)
        self.pinnedDomains = Set(pinnedDomains)
    }

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host

        // Only apply pinning to configured domains (or all if empty)
        if !pinnedDomains.isEmpty && !pinnedDomains.contains(host) {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Evaluate the trust chain
        var error: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &error) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Check each certificate in the chain for a matching SPKI hash
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        var matched = false

        for certificate in certificateChain {
            // Extract the public key
            guard let publicKey = SecCertificateCopyKey(certificate) else {
                continue
            }

            // Get the SPKI data
            guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
                continue
            }

            // Compute SHA-256 hash of the SPKI
            let hash = SHA256.hash(data: publicKeyData)
            let hashBase64 = Data(hash).base64EncodedString()

            if pinnedHashes.contains(hashBase64) {
                matched = true
                break
            }
        }

        if matched {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            // Pin mismatch — reject the connection
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - APIClient Integration

extension APIClient {
    /// Creates an APIClient with certificate pinning enabled.
    ///
    /// - Parameters:
    ///   - baseURL: Base URL for API requests.
    ///   - tokenProvider: Provider for JWT tokens.
    ///   - pinnedHashes: SPKI SHA-256 hashes (base64-encoded) for the API server.
    ///   - pinnedDomains: Domains to apply pinning to.
    /// - Returns: A configured APIClient with pinning.
    public static func withPinning(
        baseURL: URL,
        tokenProvider: TokenProvider,
        pinnedHashes: [String],
        pinnedDomains: [String] = []
    ) -> APIClient {
        let pinningDelegate = CertificatePinningDelegate(
            pinnedHashes: pinnedHashes,
            pinnedDomains: pinnedDomains
        )
        let session = URLSession(
            configuration: .default,
            delegate: pinningDelegate,
            delegateQueue: nil
        )
        return APIClient(
            baseURL: baseURL,
            tokenProvider: tokenProvider,
            session: session
        )
    }
}
