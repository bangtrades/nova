import Foundation

/// Represents a single lesson in a learning path.
///
/// Lessons are composed of cards and can be auto-generated from URLs or created manually.
/// Each lesson can contain AI analysis for quality and age-appropriateness.
public struct Lesson: Codable, Identifiable {
    /// Unique identifier for the lesson.
    public let id: UUID

    /// ID of the learning path this lesson belongs to (optional for orphaned lessons).
    public var pathId: UUID?

    /// ID of the user who created this lesson.
    public let userId: UUID

    /// Title of the lesson.
    public var title: String

    /// Description of what the lesson teaches.
    public var description: String

    /// URL to a thumbnail image for the lesson.
    public var thumbnailURL: URL?

    /// Difficulty level (1: easy, 2: medium, 3: hard).
    public var difficulty: Int

    /// URL of the source content (webpage, PDF, etc.).
    public var sourceURL: URL?

    /// AI-generated analysis of the lesson content.
    public var aiAnalysis: AIAnalysis?

    /// Current status of the lesson (draft, generating, review, published).
    public var status: LessonStatus

    /// Display order within the path.
    public var sortOrder: Int

    /// Date and time when the lesson was created.
    public let createdAt: Date

    /// Date and time when the lesson was published (if applicable).
    public var publishedAt: Date?

    /// Cards that make up this lesson (loaded optionally).
    public var cards: [Card]?

    /// Coding keys for snake_case JSON decoding.
    enum CodingKeys: String, CodingKey {
        case id
        case pathId
        case userId
        case title
        case description
        case thumbnailURL = "thumbnailUrl"
        case difficulty
        case sourceURL = "sourceUrl"
        case aiAnalysis
        case status
        case sortOrder
        case createdAt
        case publishedAt
        case cards
    }

    /// Status of a lesson in its lifecycle.
    public enum LessonStatus: String, Codable {
        case draft
        case generating
        case review
        case published
    }

    /// AI-generated analysis of lesson content.
    public struct AIAnalysis: Codable {
        /// Main topic or theme of the lesson.
        public var topic: String

        /// Recommended learning stage for this content.
        public var suggestedStage: ChildProfile.Stage

        /// Array of key concepts covered in the lesson.
        public var keyConceptsArray: [String]

        /// Score (0-1) indicating age-appropriateness for target stage.
        public var ageAppropriatenessScore: Double

        /// Array of content flags (violence, unsafe, etc.) if any.
        public var flaggedContent: [String]?

        /// Coding keys for snake_case JSON decoding.
        enum CodingKeys: String, CodingKey {
            case topic
            case suggestedStage
            case keyConceptsArray
            case ageAppropriatenessScore
            case flaggedContent
        }

        /// Initializes a new AIAnalysis.
        public init(
            topic: String,
            suggestedStage: ChildProfile.Stage,
            keyConceptsArray: [String],
            ageAppropriatenessScore: Double,
            flaggedContent: [String]? = nil
        ) {
            self.topic = topic
            self.suggestedStage = suggestedStage
            self.keyConceptsArray = keyConceptsArray
            self.ageAppropriatenessScore = ageAppropriatenessScore
            self.flaggedContent = flaggedContent
        }
    }

    /// Initializes a new Lesson.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - pathId: ID of the learning path.
    ///   - userId: User who created the lesson.
    ///   - title: Lesson title.
    ///   - description: Lesson description.
    ///   - thumbnailURL: Thumbnail image URL.
    ///   - difficulty: Difficulty level (1-3).
    ///   - sourceURL: Source content URL.
    ///   - aiAnalysis: AI analysis results.
    ///   - status: Current status.
    ///   - sortOrder: Display order.
    ///   - createdAt: Creation date (defaults to now).
    ///   - publishedAt: Publication date.
    ///   - cards: Lesson cards (optional).
    public init(
        id: UUID = UUID(),
        pathId: UUID? = nil,
        userId: UUID,
        title: String,
        description: String,
        thumbnailURL: URL? = nil,
        difficulty: Int,
        sourceURL: URL? = nil,
        aiAnalysis: AIAnalysis? = nil,
        status: LessonStatus = .draft,
        sortOrder: Int,
        createdAt: Date = Date(),
        publishedAt: Date? = nil,
        cards: [Card]? = nil
    ) {
        self.id = id
        self.pathId = pathId
        self.userId = userId
        self.title = title
        self.description = description
        self.thumbnailURL = thumbnailURL
        self.difficulty = difficulty
        self.sourceURL = sourceURL
        self.aiAnalysis = aiAnalysis
        self.status = status
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.publishedAt = publishedAt
        self.cards = cards
    }
}
