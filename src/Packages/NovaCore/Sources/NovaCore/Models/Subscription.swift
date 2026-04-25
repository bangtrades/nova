import Foundation

/// Represents a subscription for a user account.
///
/// Tracks subscription status, plan type, and StoreKit transaction information.
public struct Subscription: Codable, Identifiable {
    /// Unique identifier for the subscription.
    public let id: UUID

    /// ID of the user who owns this subscription.
    public let userId: UUID

    /// Subscription plan type.
    public var plan: SubscriptionPlan

    /// StoreKit transaction ID for verification.
    public var storeKitTransactionId: String?

    /// Current status of the subscription.
    public var status: SubscriptionStatus

    /// Date when the subscription expires.
    public var expiresAt: Date?

    /// Date when the subscription was created.
    public let createdAt: Date

    /// Coding keys for snake_case JSON decoding.
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case plan
        case storeKitTransactionId
        case status
        case expiresAt
        case createdAt
    }

    /// Subscription plan tier.
    public enum SubscriptionPlan: String, Codable {
        case free
        case pro
        case byok // Bring Your Own Key (for LLM providers)
    }

    /// Status of a subscription.
    public enum SubscriptionStatus: String, Codable {
        case active
        case expired
        case cancelled
        case gracePeriod
        case billingRetry
    }

    /// Computed property: whether the subscription is currently active.
    public var isActive: Bool {
        return status == .active
    }

    /// Initializes a new Subscription.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - userId: User who owns this subscription.
    ///   - plan: Subscription plan type.
    ///   - storeKitTransactionId: StoreKit transaction ID.
    ///   - status: Current status.
    ///   - expiresAt: Expiration date.
    ///   - createdAt: Creation date (defaults to now).
    public init(
        id: UUID = UUID(),
        userId: UUID,
        plan: SubscriptionPlan,
        storeKitTransactionId: String? = nil,
        status: SubscriptionStatus,
        expiresAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.plan = plan
        self.storeKitTransactionId = storeKitTransactionId
        self.status = status
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }
}

/// Represents a connected LLM provider for a user.
///
/// Users can connect external LLM services (OpenAI, Gemini, etc.) to generate
/// lesson content and provide analysis.
public struct LLMProvider: Codable, Identifiable {
    /// Unique identifier for the provider connection.
    public let id: UUID

    /// ID of the user who connected this provider.
    public let userId: UUID

    /// Type of LLM provider.
    public var provider: LLMProviderType

    /// Current connection status.
    public var status: ProviderStatus

    /// Date when the provider was connected.
    public let connectedAt: Date

    /// Coding keys for snake_case JSON decoding.
    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case provider
        case status
        case connectedAt
    }

    /// Type of LLM provider.
    public enum LLMProviderType: String, Codable {
        case openai
        // Future providers:
        // case gemini
        // case anthropic
    }

    /// Status of an LLM provider connection.
    public enum ProviderStatus: String, Codable {
        case active
        case expired
        case revoked
    }

    /// Computed property: whether the provider is usable.
    public var isActive: Bool {
        return status == .active
    }

    /// Initializes a new LLMProvider.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - userId: User who connected this provider.
    ///   - provider: Provider type.
    ///   - status: Connection status.
    ///   - connectedAt: Connection timestamp (defaults to now).
    public init(
        id: UUID = UUID(),
        userId: UUID,
        provider: LLMProviderType,
        status: ProviderStatus,
        connectedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.provider = provider
        self.status = status
        self.connectedAt = connectedAt
    }
}
