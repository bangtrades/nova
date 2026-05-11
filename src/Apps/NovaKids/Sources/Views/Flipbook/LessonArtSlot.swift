import SwiftUI
import UIKit

/// Centralized lookup for the NovaKids lesson-page art slots.
///
/// **Why this exists.** The lesson reader is being prepared for a
/// rolling import of generated workbook art. Before this enum existed,
/// each card view (`StoryCardView`, `ConceptCardView`, `QuizCardView`,
/// `ExperimentCardView`, `VoiceCardView`, `LessonBookPageSurface`,
/// `LessonBookReaderShell`) hard-coded the imageset names it expected
/// (`lesson_storybook_frame_45_landscape`,
/// `lesson_answer_tiles_45_landscape`, `lesson_voice_prompt_45`, etc.).
/// That meant a designer dropping a newly-named asset into the catalog
/// could not predict where to wire it without grepping every card
/// view, and a typo in any one card view would silently fall back to
/// the SwiftUI placeholder without anyone noticing.
///
/// `LessonArtSlot` is the single source of truth for those imageset
/// names. Each slot lists its canonical name (matching the vault asset
/// list at
/// `cortana-vault/projects/novai/novai--v2-beta-art-asset-list.md`)
/// **plus any legacy alias** that already ships in the asset catalog
/// today. The lookup walks the candidates in order, so a designer can
/// drop a vault-named PNG into Xcode and have it picked up
/// automatically without removing the legacy placeholder.
///
/// ## Usage
///
/// ```swift
/// @ViewBuilder
/// private var answerTrayBackground: some View {
///     if let name = LessonArtSlot.quizAnswerTilesTray.resolvedName {
///         Image(name)
///             .resizable()
///             .scaledToFill()
///             .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
///             .allowsHitTesting(false)
///             .accessibilityHidden(true)
///     } else {
///         RoundedRectangle(cornerRadius: 16, style: .continuous)
///             .fill(NovaPalette.classroomPaper.opacity(0.55))
///     }
/// }
/// ```
///
/// ## Contract
///
/// - **Live text stays in SwiftUI.** Each slot describes a *background*
///   or *decorative* asset only. No slot is allowed to bake readable
///   text into the image; the comments next to each case re-state that
///   rule for the next designer.
/// - **Missing assets degrade gracefully.** `resolvedName` returns
///   `nil` when no candidate is in the bundle, and call sites are
///   expected to fall back to a SwiftUI material. The lookup never
///   returns a string that doesn't resolve via `UIImage(named:)`.
/// - **Vault-canonical names win.** When both a canonical name and a
///   legacy alias resolve, the canonical name is preferred so a
///   half-finished migration doesn't silently regress to a placeholder.
public enum LessonArtSlot: String, CaseIterable {
    // MARK: - Story

    /// Empty picture frame around a story illustration. Frame artwork
    /// only — the inner image is rendered by `CardHeroImage` on top.
    case storyPictureFrame

    /// Pinned-paper background for the story page (storybook page
    /// material). Tape/pin corners, no text.
    case storyPinnedIllustrationCard

    /// Decorative tape strip set used on story corners. Optional.
    case storyTapeCorners

    /// "What story is this?" bookmark sticker shown on the story card
    /// header strip.
    case storyBookmark

    /// Friendly blank picture frame shown when a story card has no
    /// hero image URL. No text in the asset.
    case storyBlankPicturePlaceholder

    // MARK: - Concept

    /// Chalk diagram board used as the concept-card hero. Empty
    /// center area — SwiftUI labels render on top.
    case conceptChalkDiagramBoard

    /// Workbook-style worksheet page background used for concept
    /// "big idea" notes.
    case conceptWorksheetPage

    /// Magnifier sticker for concept-card focus.
    case conceptMagnifier

    // MARK: - Quiz

    /// Sticky-note background under the quiz question copy.
    case quizQuestionStickyNote

    /// Tray / paper backdrop hosting the answer tile column.
    case quizAnswerTilesTray

    /// Idle answer-tile background. SwiftUI fallback is the magnetic
    /// tile in `QuizAnswerButton`.
    case quizAnswerTileIdle

    /// Selected/committed answer tile.
    case quizAnswerTileSelected

    /// Correct-answer tile (post-evaluation).
    case quizAnswerTileCorrect

    /// Wrong-answer tile (post-evaluation).
    case quizAnswerTileWrong

    /// Hint-note paper used in `QuizCardView.hintPill`.
    case quizHintNote

    /// Optional sticker burst over a correct answer.
    case quizFeedbackCorrectBurst

    /// Optional friendly retry note for repeated wrong answers.
    case quizFeedbackTryAgainNote

    // MARK: - Experiment

    /// Tabletop activity surface (landscape).
    case experimentTabletopLandscape

    /// Tabletop activity surface (portrait).
    case experimentTabletopPortrait

    /// Drop-zone target — blank, visually obvious.
    case experimentDropZone

    /// Source tray that holds draggable tiles.
    case experimentMaterialTray

    /// Generic blank draggable tile.
    case experimentDragTile

    /// Optional success card shown on completion.
    case experimentSuccessCard

    // MARK: - Voice

    /// Idle microphone object.
    case voiceMicrophoneIdle

    /// Microphone in listening state — glow / wave treatment baked in.
    case voiceMicrophoneListening

    /// Microphone in success state.
    case voiceMicrophoneSuccess

    /// Wave ring overlay used while recording.
    case voiceWaveRing

    /// Speech-bubble background hosting the prompt copy.
    case voicePromptBubble

    /// Friendly retry bubble for missed responses.
    case voiceRetryBubble

    // MARK: - Read-aloud (shared by Story / Concept)

    /// Idle read-page button object.
    case readAloudButtonIdle

    /// Active "reading" state for the read-page button.
    case readAloudButtonReading

    /// "Stop" state for the read-page button.
    case readAloudButtonStop

    /// Audio wave ring overlay rendered around the read button while
    /// reading.
    case readAloudWaveRing

    // MARK: - Reader chrome (workbook + book-page surfaces)

    /// Open-workbook background used by `LessonBookReaderShell`
    /// (landscape).
    case readerWorkbookLandscape

    /// Open-workbook background (portrait variant).
    case readerWorkbookPortrait

    /// Foreground desk slab used by `LessonBookReaderShell`.
    case readerDeskLandscape

    /// Page-turn affordance used by the reader's previous/next
    /// buttons.
    case readerPageTurn

    /// Storybook page paper — used by
    /// `LessonBookPageSurface(mood: .storybook)`.
    case bookPageStorybook

    /// Workbook worksheet paper — used by
    /// `LessonBookPageSurface(mood: .workbook)`.
    case bookPageWorkbook

    // MARK: - Resolution

    /// Imageset name candidates for this slot, in preferred order.
    /// The first entry is the vault-canonical name; subsequent
    /// entries are legacy aliases that still ship in
    /// `Assets.xcassets` today so a partial migration does not break
    /// production.
    public var candidates: [String] {
        switch self {
        // Story
        case .storyPictureFrame:
            return ["lesson_story_picture_frame_45", "lesson_storybook_frame_45_landscape"]
        case .storyPinnedIllustrationCard:
            return ["lesson_story_pinned_illustration_card_45"]
        case .storyTapeCorners:
            return ["lesson_story_tape_corners_45"]
        case .storyBookmark:
            return ["lesson_story_bookmark_45", "lesson_bookmark_45"]
        case .storyBlankPicturePlaceholder:
            return ["lesson_story_blank_picture_placeholder_45"]

        // Concept
        case .conceptChalkDiagramBoard:
            return ["lesson_concept_chalk_diagram_board_45", "lesson_chalkpanel_45_landscape"]
        case .conceptWorksheetPage:
            return ["lesson_concept_worksheet_page_45", "lesson_workbook_worksheet_45_landscape"]
        case .conceptMagnifier:
            return ["lesson_concept_magnifier_45"]

        // Quiz
        case .quizQuestionStickyNote:
            return ["lesson_quiz_question_sticky_note_45"]
        case .quizAnswerTilesTray:
            return ["lesson_quiz_answer_tiles_45", "lesson_answer_tiles_45_landscape"]
        case .quizAnswerTileIdle:
            return ["lesson_quiz_answer_tile_idle_45"]
        case .quizAnswerTileSelected:
            return ["lesson_quiz_answer_tile_selected_45"]
        case .quizAnswerTileCorrect:
            return ["lesson_quiz_answer_tile_correct_45"]
        case .quizAnswerTileWrong:
            return ["lesson_quiz_answer_tile_wrong_45"]
        case .quizHintNote:
            return ["lesson_quiz_hint_note_45", "lesson_hint_note_45"]
        case .quizFeedbackCorrectBurst:
            return ["lesson_quiz_feedback_correct_burst_45"]
        case .quizFeedbackTryAgainNote:
            return ["lesson_quiz_feedback_try_again_note_45"]

        // Experiment
        case .experimentTabletopLandscape:
            return ["lesson_experiment_tabletop_45_landscape", "lesson_experiment_table_45_landscape"]
        case .experimentTabletopPortrait:
            return ["lesson_experiment_tabletop_45_portrait"]
        case .experimentDropZone:
            return ["lesson_experiment_drop_zone_45"]
        case .experimentMaterialTray:
            return ["lesson_experiment_material_tray_45"]
        case .experimentDragTile:
            return ["lesson_experiment_drag_tile_45"]
        case .experimentSuccessCard:
            return ["lesson_experiment_success_card_45"]

        // Voice
        case .voiceMicrophoneIdle:
            return ["lesson_voice_microphone_idle_45"]
        case .voiceMicrophoneListening:
            return ["lesson_voice_microphone_listening_45"]
        case .voiceMicrophoneSuccess:
            return ["lesson_voice_microphone_success_45"]
        case .voiceWaveRing:
            return ["lesson_voice_wave_ring_45"]
        case .voicePromptBubble:
            return ["lesson_voice_prompt_bubble_45", "lesson_voice_prompt_45"]
        case .voiceRetryBubble:
            return ["lesson_voice_retry_bubble_45"]

        // Read-aloud
        case .readAloudButtonIdle:
            return ["lesson_read_page_button_idle_45", "lesson_read_aloud_45"]
        case .readAloudButtonReading:
            return ["lesson_read_page_button_reading_45"]
        case .readAloudButtonStop:
            return ["lesson_read_page_button_stop_45"]
        case .readAloudWaveRing:
            return ["lesson_audio_wave_ring_45"]

        // Reader chrome
        case .readerWorkbookLandscape:
            return ["lesson_workbook_45_landscape"]
        case .readerWorkbookPortrait:
            return ["lesson_workbook_45_portrait"]
        case .readerDeskLandscape:
            return ["lesson_reader_desk_45_landscape", "lesson_desktop_45_landscape"]
        case .readerPageTurn:
            return ["lesson_page_turn_right_45", "lesson_page_turn_45"]
        case .bookPageStorybook:
            return ["lesson_storybook_page_45_landscape"]
        case .bookPageWorkbook:
            return ["lesson_workbook_worksheet_45_landscape"]
        }
    }

    /// First candidate that exists in the running app's asset catalog,
    /// or `nil` if none of the candidates resolve. Call sites should
    /// fall back to a SwiftUI material when this returns `nil`.
    public var resolvedName: String? {
        Self.resolvedNameCache[self]
    }

    private static let resolvedNameCache: [LessonArtSlot: String] = {
        Dictionary(
            uniqueKeysWithValues: allCases.compactMap { slot in
                slot.firstResolvedCandidate.map { (slot, $0) }
            }
        )
    }()

    private var firstResolvedCandidate: String? {
        for name in candidates where UIImage(named: name) != nil {
            return name
        }
        return nil
    }

    /// True when at least one candidate resolves. Convenience for
    /// branching at the call site without needing to bind the
    /// resolved name.
    public var hasAsset: Bool {
        resolvedName != nil
    }
}
