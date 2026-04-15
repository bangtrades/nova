import Foundation

/// Represents a curated learning path in the Nova system.
///
/// A learning path is a collection of lessons organized around a specific theme or topic,
/// designed for a particular learning stage and user.
public struct LearningPath: Codable, Identifiable {
    /// Unique identifier for the learning path.
    public let id: UUID

    /// ID of the user who created or owns this path.
    public let userId: UUID

    /// Title of the learning path.
    public var title: String

    /// Detailed description of what the path teaches.
    public var description: String

    /// Color identifier for UI display (hex string or color name).
    public var color: String

    /// Icon identifier for UI display (SF Symbol or custom name).
    public var icon: String

    /// Display order among paths.
    public var sortOrder: Int

    /// Target learning stage for this path.
    public var stage: ChildProfile.Stage

    /// Whether this path requires a premium subscription.
    public var isPremium: Bool

    /// Lessons associated with this path (loaded optionally).
    public var lessons: [Lesson]?

    /// When this path was created.
    public var createdAt: Date

    /// When this path was last updated.
    public var updatedAt: Date

    /// Coding keys for snake_case JSON decoding.
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case description
        case color
        case icon
        case sortOrder = "sort_order"
        case stage
        case isPremium = "is_premium"
        case lessons
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Initializes a new LearningPath.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - userId: User who created this path.
    ///   - title: Path title.
    ///   - description: Path description.
    ///   - color: Color for display.
    ///   - icon: Icon identifier.
    ///   - sortOrder: Display order.
    ///   - stage: Target learning stage.
    ///   - isPremium: Whether the path requires premium.
    ///   - lessons: Lessons in the path (optional).
    ///   - createdAt: Creation date.
    ///   - updatedAt: Last update date.
    public init(
        id: UUID = UUID(),
        userId: UUID,
        title: String,
        description: String,
        color: String,
        icon: String,
        sortOrder: Int,
        stage: ChildProfile.Stage,
        isPremium: Bool = false,
        lessons: [Lesson]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.description = description
        self.color = color
        self.icon = icon
        self.sortOrder = sortOrder
        self.stage = stage
        self.isPremium = isPremium
        self.lessons = lessons
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
