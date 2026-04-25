import Foundation

/// Represents a learning session for a child.
///
/// A session tracks when a child starts and finishes a learning activity,
/// including the device they're using.
public struct LearningSession: Codable, Identifiable {
    /// Unique identifier for the session.
    public let id: UUID

    /// ID of the child participating in this session.
    public let childId: UUID

    /// Date and time when the session started.
    public let startedAt: Date

    /// Date and time when the session ended (if completed).
    public var endedAt: Date?

    /// Device identifier (for analytics).
    public var deviceId: String?

    /// Coding keys for snake_case JSON decoding.
    enum CodingKeys: String, CodingKey {
        case id
        case childId
        case startedAt
        case endedAt
        case deviceId
    }

    /// Computed property: session duration in seconds.
    public var durationSeconds: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    /// Initializes a new LearningSession.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - childId: ID of the child.
    ///   - startedAt: Session start time (defaults to now).
    ///   - endedAt: Session end time.
    ///   - deviceId: Device identifier.
    public init(
        id: UUID = UUID(),
        childId: UUID,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        deviceId: String? = nil
    ) {
        self.id = id
        self.childId = childId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.deviceId = deviceId
    }
}

/// Represents a single interaction event on a card.
///
/// Tracks what the child did with a card, how long they spent, and what the outcome was.
public struct CardInteraction: Codable, Identifiable {
    /// Unique identifier for the interaction.
    public let id: UUID

    /// ID of the session this interaction belongs to.
    public let sessionId: UUID

    /// ID of the card the child interacted with.
    public let cardId: UUID

    /// Type of action performed.
    public var action: InteractionAction

    /// Duration of the interaction in milliseconds.
    public var durationMs: Int

    /// Transcribed voice input (if applicable).
    public var voiceTranscript: String?

    /// Result of the interaction (correctness, choices, score).
    public var result: InteractionResult?

    /// Date and time of the interaction.
    public let timestamp: Date

    /// Coding keys for snake_case JSON decoding.
    enum CodingKeys: String, CodingKey {
        case id
        case sessionId
        case cardId
        case action
        case durationMs
        case voiceTranscript
        case result
        case timestamp
    }

    /// Type of action a child performed on a card.
    public enum InteractionAction: String, Codable {
        case viewed
        case completed
        case skipped
        case voiceInput
        case experimentAttempt
    }

    /// Result data from an interaction.
    public struct InteractionResult: Codable {
        /// Whether the interaction result was correct (if applicable).
        public var correct: Bool?

        /// Array of choices made by the child.
        public var choicesMade: [String]?

        /// Numeric score earned (0-1 or 0-100).
        public var score: Double?

        /// Coding keys for snake_case JSON decoding.
        enum CodingKeys: String, CodingKey {
            case correct
            case choicesMade
            case score
        }

        /// Initializes a new InteractionResult.
        public init(correct: Bool? = nil, choicesMade: [String]? = nil, score: Double? = nil) {
            self.correct = correct
            self.choicesMade = choicesMade
            self.score = score
        }
    }

    /// Initializes a new CardInteraction.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - sessionId: ID of the learning session.
    ///   - cardId: ID of the card.
    ///   - action: Type of action performed.
    ///   - durationMs: Duration in milliseconds.
    ///   - voiceTranscript: Transcribed voice input.
    ///   - result: Interaction result data.
    ///   - timestamp: Timestamp of the interaction (defaults to now).
    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        cardId: UUID,
        action: InteractionAction,
        durationMs: Int,
        voiceTranscript: String? = nil,
        result: InteractionResult? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.cardId = cardId
        self.action = action
        self.durationMs = durationMs
        self.voiceTranscript = voiceTranscript
        self.result = result
        self.timestamp = timestamp
    }
}
