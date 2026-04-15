import Foundation
import CryptoKit

/// Provides AES-GCM encrypted storage for sensitive child data (COPPA compliance).
///
/// Wraps UserDefaults with symmetric encryption using a device-bound key
/// stored in the Keychain. All child PII (names, birthdates, interaction history)
/// must be stored through this class instead of raw UserDefaults.
public final class EncryptedStorage {
    /// Shared singleton instance.
    public static let shared = EncryptedStorage()

    /// Keychain service identifier for the encryption key.
    private let keychainService = "com.nova.encrypted-storage"
    private let keychainAccount = "nova.data.encryption.key"

    /// UserDefaults suite for encrypted data.
    private let defaults: UserDefaults

    // MARK: - Initialization

    public init(suiteName: String? = "com.nova.encrypted") {
        self.defaults = UserDefaults(suiteName: suiteName ?? "com.nova.encrypted") ?? .standard
    }

    // MARK: - Public API

    /// Stores a Codable value with AES-GCM encryption.
    /// - Parameters:
    ///   - value: The value to encrypt and store.
    ///   - key: The storage key.
    public func store<T: Codable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        let encrypted = try encrypt(data)
        defaults.set(encrypted, forKey: key)
    }

    /// Retrieves and decrypts a Codable value.
    /// - Parameter key: The storage key.
    /// - Returns: The decrypted value, or nil if not found.
    public func load<T: Codable>(forKey key: String) throws -> T? {
        guard let encrypted = defaults.data(forKey: key) else {
            return nil
        }
        let decrypted = try decrypt(encrypted)
        return try JSONDecoder().decode(T.self, from: decrypted)
    }

    /// Removes an encrypted value.
    /// - Parameter key: The storage key to remove.
    public func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
    }

    /// Removes all encrypted data (for account deletion / data rights).
    public func removeAll() {
        if let bundleId = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleId)
        }
    }

    // MARK: - Encryption

    /// Encrypts data using AES-GCM with a device-bound key.
    private func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptedStorageError.encryptionFailed
        }
        return combined
    }

    /// Decrypts AES-GCM encrypted data.
    private func decrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - Key Management

    /// Retrieves or creates the AES-256 encryption key from Keychain.
    private func getOrCreateKey() throws -> SymmetricKey {
        // Try to load existing key from Keychain
        if let existingKeyData = try? loadKeyFromKeychain() {
            return SymmetricKey(data: existingKeyData)
        }

        // Generate a new key and store it
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        try saveKeyToKeychain(keyData)
        return newKey
    }

    private func loadKeyFromKeychain() throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            throw EncryptedStorageError.keyNotFound
        }
        return data
    }

    private func saveKeyToKeychain(_ keyData: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Delete any existing key first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptedStorageError.keychainWriteFailed(status)
        }
    }
}

// MARK: - Errors

public enum EncryptedStorageError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case keyNotFound
    case keychainWriteFailed(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .keyNotFound:
            return "Encryption key not found in Keychain"
        case .keychainWriteFailed(let status):
            return "Failed to save encryption key to Keychain (OSStatus: \(status))"
        }
    }
}
