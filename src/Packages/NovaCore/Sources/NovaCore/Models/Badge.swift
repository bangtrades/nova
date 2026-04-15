import Foundation

/// Represents a badge that can be earned by completing learning activities.
///
/// Badges recognize achievements such as completing lessons, maintaining streaks,
/// and exploring different types of content.
public struct Badge: Codable, Identifiable {
    /// Unique identifier for the badge.
    public let id: UUID

    /// Title of the badge.
    public var title: String

    /// Description of what the badge represents.
    public var description: String

    /// Icon identifier for the badge (SF Symbol or custom name).
    public var icon: String

    /// Criteria for earning this badge.
    public var criteria: BadgeCriteria

    /// Coding keys for snake_case JSON decoding.
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case icon
        case criteria
    }

    /// Initializes a new Badge.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - title: Badge title.
    ///   - description: Badge description.
    ///   - icon: Icon identifier.
    ///   - criteria: Criteria for earning this badge.
    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        icon: String,
        criteria: BadgeCriteria
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.criteria = criteria
    }
}

/// Criteria for earning a badge.
public struct BadgeCriteria: Codable {
    /// Type of criterion.
    public var type: BadgeCriteriaType

    /// Number of actions required to earn the badge.
    public var count: Int

    /// Coding keys for snake_case JSON decoding.
    enum CodingKeys: String, CodingKey {
        case type
        case count
    }

    /// Type of achievement criterion.
    public enum BadgeCriteriaType: String, Codable {
        case lessonsCompleted
        case experimentsCompleted
        case daysStreak
        case voiceInteractions
        case pathCompleted
    }

    /// Initializes a new BadgeCriteria.
    /// - Parameters:
    ///   - type: Type of criterion.
    ///   - count: Required count for earning.
    public init(type: BadgeCriteriaType, count: Int) {
        self.type = type
        self.count = count
    }
}

/// Represents a badge that has been earned by a child.
///
/// Tracks when a child earned a specific badge.
public struct EarnedBadge: Codable, Identifiable {
    /// Unique identifier for the earned badge record.
    public let id: UUID

    /// ID of the child who earned this badge.
    public let childId: UUID

    /// ID of the badge definition.
    public let badgeId: UUID

    /// Date and time when the badge was earned.
    public let earnedAt: Date

    /// Coding keys for snake_case JSON decoding.
    enum CodingKeys: String, CodingKey {
        case id
        case childId = "child_id"
        case badgeId = "badge_id"
        case earnedAt = "earned_at"
    }

    /// Initializes a new EarnedBadge.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - childId: ID of the child.
    ///   - badgeId: ID of the badge.
    ///   - earnedAt: Earned timestamp (defaults to now).
    public init(
        id: UUID = UUID(),
        childId: UUID,
        badgeId: UUID,
        earnedAt: Date = Date()
    ) {
        self.id = id
        self.childId = childId
        self.badgeId = badgeId
        self.earnedAt = earnedAt
    }
}
