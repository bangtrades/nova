import Foundation

/// Represents a child's learning profile in the Nova system.
///
/// Each user can have multiple child profiles, each progressing through
/// different learning stages (Explorer, Thinker, Maker, Creator).
public struct ChildProfile: Codable, Identifiable {
    /// Unique identifier for the child profile.
    public let id: UUID

    /// ID of the parent user who created this profile.
    public let userId: UUID

    /// Child's name.
    public var name: String

    /// Child's birthdate.
    public var birthDate: Date

    /// URL to the child's avatar image.
    public var avatarURL: URL?

    /// Current learning stage (1-4: Explorer, Thinker, Maker, Creator).
    public var currentStage: Int = 1

    /// Date and time when this profile was created.
    public let createdAt: Date

    /// Coding keys for snake_case JSON decoding.
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case birthDate = "birth_date"
        case avatarURL = "avatar_url"
        case currentStage = "current_stage"
        case createdAt = "created_at"
    }

    /// The learning stage of the child.
    ///
    /// Each stage represents a different cognitive development level with appropriate
    /// content difficulty and interaction styles.
    public enum Stage: Int, Codable, CaseIterable {
        case explorer = 1
        case thinker = 2
        case maker = 3
        case creator = 4

        /// Human-readable display name for the stage.
        public var displayName: String {
            switch self {
            case .explorer:
                return "Explorer"
            case .thinker:
                return "Thinker"
            case .maker:
                return "Maker"
            case .creator:
                return "Creator"
            }
        }

        /// Description of what this stage represents.
        public var description: String {
            switch self {
            case .explorer:
                return "Discovering the basics of AI and technology"
            case .thinker:
                return "Understanding AI concepts and reasoning"
            case .maker:
                return "Building with AI tools and systems"
            case .creator:
                return "Creating novel AI solutions and ideas"
            }
        }
    }

    /// Computed property: child's age based on birthDate.
    public var age: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: birthDate, to: Date())
        return components.year ?? 0
    }

    /// Initializes a new ChildProfile.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - userId: Parent user's ID.
    ///   - name: Child's name.
    ///   - birthDate: Child's birthdate.
    ///   - avatarURL: URL to avatar image.
    ///   - currentStage: Current learning stage (defaults to 1: Explorer).
    ///   - createdAt: Profile creation date (defaults to now).
    public init(
        id: UUID = UUID(),
        userId: UUID,
        name: String,
        birthDate: Date,
        avatarURL: URL? = nil,
        currentStage: Int = 1,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.birthDate = birthDate
        self.avatarURL = avatarURL
        self.currentStage = currentStage
        self.createdAt = createdAt
    }
}
