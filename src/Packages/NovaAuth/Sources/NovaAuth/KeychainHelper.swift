import Foundation
import Security

/// Secure wrapper around the Keychain for storing sensitive data.
///
/// Uses the Security framework to store and retrieve passwords and other
/// sensitive information securely.
public class KeychainHelper {
    /// Saves data to the Keychain.
    ///
    /// - Parameters:
    ///   - key: The unique key for the data.
    ///   - data: The data to store.
    /// - Throws: KeychainError if the operation fails.
    public func save(key: String, data: Data) throws {
        // Delete existing value first
        try delete(key: key)

        // Create the query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]

        // Add to Keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Retrieves data from the Keychain.
    ///
    /// - Parameters:
    ///   - key: The unique key for the data.
    /// - Returns: The stored data, or nil if not found.
    public func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    /// Deletes data from the Keychain.
    ///
    /// - Parameters:
    ///   - key: The unique key for the data.
    /// - Throws: KeychainError if the operation fails (except if key not found).
    public func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)

        // errSecItemNotFound is not an error for delete
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Clears all Nova-related data from the Keychain.
    ///
    /// - Throws: KeychainError if the operation fails.
    public func clearAll() throws {
        let knownKeys = [
            "nova.auth.accessToken",
            "nova.auth.refreshToken",
        ]

        for key in knownKeys {
            try? delete(key: key)
        }
    }
}

/// Errors that can occur during Keychain operations.
public enum KeychainError: LocalizedError {
    /// Failed to save data to Keychain.
    case saveFailed(OSStatus)

    /// Failed to delete data from Keychain.
    case deleteFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain (status: \(status))"
        }
    }
}
