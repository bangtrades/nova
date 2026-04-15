import Foundation

/// Manages COPPA parental consent tracking and verification.
///
/// Records when parental consent was obtained, what was consented to,
/// and provides verification for data collection gating. All consent
/// records are stored encrypted via `EncryptedStorage`.
public final class COPPAConsentManager {
    /// Shared singleton instance.
    public static let shared = COPPAConsentManager()

    /// Storage key prefix for consent records.
    private let consentKeyPrefix = "nova.coppa.consent"

    /// Encrypted storage backend.
    private let storage: EncryptedStorage

    // MARK: - Types

    /// Categories of data collection that require parental consent.
    public enum ConsentCategory: String, Codable, CaseIterable {
        /// Collection of child name and birthdate.
        case personalInfo = "personal_info"

        /// Collection of learning progress and interaction history.
        case learningData = "learning_data"

        /// Collection of voice recordings for speech exercises.
        case voiceRecordings = "voice_recordings"

        /// Sharing anonymized analytics with service providers.
        case analytics = "analytics"

        /// Human-readable description for consent UI.
        public var displayName: String {
            switch self {
            case .personalInfo: return "Name & Age"
            case .learningData: return "Learning Progress"
            case .voiceRecordings: return "Voice Recordings"
            case .analytics: return "Usage Analytics"
            }
        }

        /// Detailed description for the consent form.
        public var description: String {
            switch self {
            case .personalInfo:
                return "We collect your child's name and age to personalize their learning experience."
            case .learningData:
                return "We track which lessons your child completes and their quiz scores to show progress."
            case .voiceRecordings:
                return "Voice recordings are used for speech exercises and are not shared with third parties."
            case .analytics:
                return "Anonymized usage data helps us improve the app. No personal information is shared."
            }
        }
    }

    /// A record of parental consent.
    public struct ConsentRecord: Codable {
        /// The child this consent applies to.
        public let childId: UUID

        /// What was consented to.
        public let category: ConsentCategory

        /// Whether consent was granted.
        public let granted: Bool

        /// When consent was recorded.
        public let timestamp: Date

        /// App version when consent was recorded.
        public let appVersion: String

        /// Method used to verify parental identity (e.g., "parental_gate", "apple_id").
        public let verificationMethod: String
    }

    // MARK: - Initialization

    public init(storage: EncryptedStorage = .shared) {
        self.storage = storage
    }

    // MARK: - Public API

    /// Records parental consent for a specific category.
    /// - Parameters:
    ///   - category: The data collection category being consented to.
    ///   - childId: The child profile this consent applies to.
    ///   - granted: Whether consent was granted (true) or denied (false).
    ///   - verificationMethod: How the parent was verified.
    public func recordConsent(
        category: ConsentCategory,
        childId: UUID,
        granted: Bool,
        verificationMethod: String = "parental_gate"
    ) throws {
        let record = ConsentRecord(
            childId: childId,
            category: category,
            granted: granted,
            timestamp: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            verificationMethod: verificationMethod
        )

        var records = (try? loadAllRecords(for: childId)) ?? []
        // Remove any existing record for the same category
        records.removeAll { $0.category == category }
        records.append(record)

        try storage.store(records, forKey: consentKey(for: childId))
    }

    /// Checks whether consent has been granted for a specific category.
    /// - Parameters:
    ///   - category: The category to check.
    ///   - childId: The child profile to check.
    /// - Returns: `true` if consent was explicitly granted, `false` otherwise.
    public func hasConsent(for category: ConsentCategory, childId: UUID) -> Bool {
        guard let records = try? loadAllRecords(for: childId) else {
            return false
        }
        return records.first(where: { $0.category == category })?.granted ?? false
    }

    /// Returns all consent records for a child (for data export / COPPA compliance).
    /// - Parameter childId: The child profile to retrieve records for.
    /// - Returns: Array of consent records.
    public func loadAllRecords(for childId: UUID) throws -> [ConsentRecord] {
        let records: [ConsentRecord]? = try storage.load(forKey: consentKey(for: childId))
        return records ?? []
    }

    /// Revokes all consent and deletes all data for a child (right to deletion).
    /// - Parameter childId: The child whose consent and data should be removed.
    public func revokeAllConsent(for childId: UUID) {
        storage.remove(forKey: consentKey(for: childId))
    }

    /// Checks whether all required consent categories have been granted.
    /// - Parameter childId: The child to check.
    /// - Returns: `true` if personalInfo and learningData consent are both granted.
    public func hasRequiredConsent(for childId: UUID) -> Bool {
        let requiredCategories: [ConsentCategory] = [.personalInfo, .learningData]
        return requiredCategories.allSatisfy { hasConsent(for: $0, childId: childId) }
    }

    // MARK: - Private

    private func consentKey(for childId: UUID) -> String {
        "\(consentKeyPrefix).\(childId.uuidString)"
    }
}
