import Foundation

/// Represents a user account in the Nova system.
///
/// Users can have multiple child profiles and access different learning paths
/// based on their subscription level.
public struct User: Codable, Identifiable {
    /// Unique identifier for the user.
    public let id: UUID

    /// Apple ID associated with the user account (from Sign in with Apple).
    public var appleId: String?

    /// Email address of the user.
    public var email: String?

    /// Display name for the user (often the parent's name).
    public var displayName: String

    /// Date and time when the user account was created.
    public let createdAt: Date

    /// Coding keys for snake_case JSON decoding.
    enum CodingKeys: String, CodingKey {
        case id
        case appleId
        case email
        case displayName
        case createdAt
    }

    /// Initializes a new User.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - appleId: Apple ID from Sign in with Apple.
    ///   - email: User's email address.
    ///   - displayName: Display name for the user.
    ///   - createdAt: Account creation date (defaults to now).
    public init(
        id: UUID = UUID(),
        appleId: String? = nil,
        email: String? = nil,
        displayName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.appleId = appleId
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
    }
}
