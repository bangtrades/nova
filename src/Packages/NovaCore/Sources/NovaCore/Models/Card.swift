import Foundation

/// Represents a single card within a lesson.
///
/// Cards are the atomic building blocks of lessons, each containing a specific type of content
/// and interaction. Types include story, concept, experiment, quiz, voice, and video.
public struct Card: Codable, Identifiable, Equatable {
    /// Unique identifier for the card.
    public let id: UUID

    /// ID of the lesson this card belongs to.
    public let lessonId: UUID

    /// Type of card (story, concept, experiment, quiz, voice, video).
    public var type: CardType

    /// Display order within the lesson.
    public var sortOrder: Int

    /// Content data for this card (covers all card types).
    public var content: CardContent

    /// Voice narration script for the card.
    public var voiceScript: String?

    /// URL to an image associated with the card.
    public var imageURL: URL?

    /// URL to audio file (for voice or audio cards).
    public var audioURL: URL?

    /// Configuration for interactions on this card.
    public var interactionConfig: InteractionConfig?

    /// When this card was created.
    public var createdAt: Date

    /// Coding keys for snake_case JSON decoding.
    enum CodingKeys: String, CodingKey {
        case id
        case lessonId = "lesson_id"
        case type
        case sortOrder = "sort_order"
        case content
        case voiceScript = "voice_script"
        case imageURL = "image_url"
        case audioURL = "audio_url"
        case interactionConfig = "interaction_config"
        case createdAt = "created_at"
    }

    /// Type of card defining the interaction and content style.
    public enum CardType: String, Codable, CaseIterable {
        case story
        case concept
        case experiment
        case quiz
        case voice
        case video
    }

    /// Content container supporting all card types.
    ///
    /// This struct holds optional properties for each card type, allowing flexible
    /// serialization without needing separate types for each card variant.
    public struct CardContent: Codable, Equatable {
        /// Generic title for the card content.
        public var title: String?

        /// Main body text for story, concept, or instructional content.
        public var bodyText: String?

        /// Prompt for AI image generation.
        public var imagePrompt: String?

        // Story-specific
        /// Narrative text for story cards.
        public var narrativeText: String?

        // Concept-specific
        /// Explanation text for concept cards.
        public var explanation: String?

        // Experiment-specific
        /// Instructions for conducting an experiment.
        public var instructions: String?

        /// Items that can be dragged in an experiment.
        public var dragItems: [DragItem]?

        /// Drop targets for dragging interactions.
        public var dropTargets: [DropTarget]?

        // Quiz-specific
        /// Question text for quiz cards.
        public var question: String?

        /// Answer options for quiz cards.
        public var options: [QuizOption]?

        /// Index of the correct answer option.
        public var correctOptionIndex: Int?

        // Voice-specific
        /// Prompt text asking for voice input.
        public var promptText: String?

        /// Expected voice responses for validation. The speech-recognition
        /// transcript is matched against this list (case-insensitive,
        /// whitespace-normalized, prefix + contains match) to decide
        /// whether to play `celebration` or `retryHint`.
        public var expectedResponses: [String]?

        /// S12-06 voice-persona: Dashy's shared-win line spoken via TTS
        /// on a successful match. 6–80 chars, first-person.
        public var celebration: String?

        /// S12-06 voice-persona: Dashy's soft-reset line spoken via TTS
        /// on a miss. 6–80 chars, first-person, no hard corrections.
        public var retryHint: String?

        /// S12-06 voice-persona: optional kebab-syllable pronunciation
        /// hint (e.g. "pho-to-syn-the-sis") passed to AVSpeechUtterance
        /// for clean TTS articulation of multi-syllable target words.
        public var phonetics: String?

        // Video-specific
        /// URL to the video content.
        public var videoURL: URL?

        /// Pause points in the video (seconds) for breakpoints.
        public var pausePoints: [Double]?

        /// Coding keys for snake_case JSON decoding.
        enum CodingKeys: String, CodingKey {
            case title
            case bodyText = "body_text"
            case imagePrompt = "image_prompt"
            case narrativeText = "narrative_text"
            case explanation
            case instructions
            case dragItems = "drag_items"
            case dropTargets = "drop_targets"
            case question
            case options
            case correctOptionIndex = "correct_option_index"
            case promptText = "prompt_text"
            case expectedResponses = "expected_responses"
            case celebration
            case retryHint = "retry_hint"
            case phonetics
            case videoURL = "video_url"
            case pausePoints = "pause_points"
        }

        /// Initializes a new CardContent.
        public init(
            title: String? = nil,
            bodyText: String? = nil,
            imagePrompt: String? = nil,
            narrativeText: String? = nil,
            explanation: String? = nil,
            instructions: String? = nil,
            dragItems: [DragItem]? = nil,
            dropTargets: [DropTarget]? = nil,
            question: String? = nil,
            options: [QuizOption]? = nil,
            correctOptionIndex: Int? = nil,
            promptText: String? = nil,
            expectedResponses: [String]? = nil,
            celebration: String? = nil,
            retryHint: String? = nil,
            phonetics: String? = nil,
            videoURL: URL? = nil,
            pausePoints: [Double]? = nil
        ) {
            self.title = title
            self.bodyText = bodyText
            self.imagePrompt = imagePrompt
            self.narrativeText = narrativeText
            self.explanation = explanation
            self.instructions = instructions
            self.dragItems = dragItems
            self.dropTargets = dropTargets
            self.question = question
            self.options = options
            self.correctOptionIndex = correctOptionIndex
            self.promptText = promptText
            self.expectedResponses = expectedResponses
            self.celebration = celebration
            self.retryHint = retryHint
            self.phonetics = phonetics
            self.videoURL = videoURL
            self.pausePoints = pausePoints
        }
    }

    /// An item that can be dragged in an experiment card.
    public struct DragItem: Codable, Identifiable, Equatable {
        /// Unique identifier for the drag item.
        public let id: String

        /// Label text displayed on the item.
        public var label: String

        /// Image URL for the item visual.
        public var imageURL: URL?

        /// Coding keys for snake_case JSON decoding.
        enum CodingKeys: String, CodingKey {
            case id
            case label
            case imageURL = "image_url"
        }

        /// Initializes a new DragItem.
        public init(id: String, label: String, imageURL: URL? = nil) {
            self.id = id
            self.label = label
            self.imageURL = imageURL
        }
    }

    /// A drop target zone for experiment cards.
    public struct DropTarget: Codable, Identifiable, Equatable {
        /// Unique identifier for the drop target.
        public let id: String

        /// Label text for the target zone.
        public var label: String

        /// IDs of drag items this target accepts.
        public var acceptsItemIds: [String]

        /// Coding keys for snake_case JSON decoding.
        enum CodingKeys: String, CodingKey {
            case id
            case label
            case acceptsItemIds = "accepts_item_ids"
        }

        /// Initializes a new DropTarget.
        public init(id: String, label: String, acceptsItemIds: [String]) {
            self.id = id
            self.label = label
            self.acceptsItemIds = acceptsItemIds
        }
    }

    /// An answer option for quiz cards.
    public struct QuizOption: Codable, Identifiable, Equatable {
        /// Unique identifier for the option.
        public let id: String

        /// Display text for the option.
        public var text: String

        /// Optional image for the option.
        public var imageURL: URL?

        /// Coding keys for snake_case JSON decoding.
        enum CodingKeys: String, CodingKey {
            case id
            case text
            case imageURL = "image_url"
        }

        /// Initializes a new QuizOption.
        public init(id: String, text: String, imageURL: URL? = nil) {
            self.id = id
            self.text = text
            self.imageURL = imageURL
        }
    }

    /// Configuration for user interactions on a card.
    public struct InteractionConfig: Codable, Equatable {
        /// Maximum number of attempts allowed.
        public var maxAttempts: Int?

        /// Number of attempts before showing a hint.
        public var showHintAfter: Int?

        /// Message displayed on successful completion.
        public var successMessage: String?

        /// Message displayed on failure.
        public var failureMessage: String?

        /// Hint message for users who struggle.
        public var hintMessage: String?

        /// Coding keys for snake_case JSON decoding.
        enum CodingKeys: String, CodingKey {
            case maxAttempts = "max_attempts"
            case showHintAfter = "show_hint_after"
            case successMessage = "success_message"
            case failureMessage = "failure_message"
            case hintMessage = "hint_message"
        }

        /// Initializes a new InteractionConfig.
        public init(
            maxAttempts: Int? = nil,
            showHintAfter: Int? = nil,
            successMessage: String? = nil,
            failureMessage: String? = nil,
            hintMessage: String? = nil
        ) {
            self.maxAttempts = maxAttempts
            self.showHintAfter = showHintAfter
            self.successMessage = successMessage
            self.failureMessage = failureMessage
            self.hintMessage = hintMessage
        }
    }

    /// Initializes a new Card.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID).
    ///   - lessonId: ID of the lesson containing this card.
    ///   - type: Card type (story, concept, experiment, quiz, voice, video).
    ///   - sortOrder: Display order.
    ///   - content: Card content data.
    ///   - voiceScript: Voice narration script.
    ///   - imageURL: Image URL.
    ///   - audioURL: Audio URL.
    ///   - interactionConfig: Interaction configuration.
    ///   - createdAt: Creation date.
    public init(
        id: UUID = UUID(),
        lessonId: UUID,
        type: CardType,
        sortOrder: Int,
        content: CardContent,
        voiceScript: String? = nil,
        imageURL: URL? = nil,
        audioURL: URL? = nil,
        interactionConfig: InteractionConfig? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.lessonId = lessonId
        self.type = type
        self.sortOrder = sortOrder
        self.content = content
        self.voiceScript = voiceScript
        self.imageURL = imageURL
        self.audioURL = audioURL
        self.interactionConfig = interactionConfig
        self.createdAt = createdAt
    }
}
