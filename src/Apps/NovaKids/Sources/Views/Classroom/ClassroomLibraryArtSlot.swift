import SwiftUI
import UIKit
import NovaCore

/// Centralized lookup for the NovaKids lesson-library / bookshelf art
/// slots — the library-side counterpart to `LessonArtSlot`.
///
/// **Why this exists.** The lesson library / Bookshelf screen
/// (`ClassroomLessonLibraryView`, `ClassroomLessonShelfSection`,
/// `ClassroomLessonBookButton`) is being prepared for a rolling
/// import of generated 2.5D bookshelf, shelf-row, book-spine, and
/// state-badge artwork. The lesson reader has `LessonArtSlot` as its
/// single source of truth for art-asset names; the library should
/// follow the same shape so a designer dropping a vault-named PNG
/// into Xcode picks up the new look without a Swift code change.
///
/// The canonical names mirror the asset list at
/// `cortana-vault/projects/novai/novai--v2-beta-art-asset-list.md`
/// (P1 "Lesson Library"). Each slot lists the canonical name first;
/// future legacy aliases can be appended without breaking call sites.
///
/// ## Usage
///
/// ```swift
/// @ViewBuilder
/// private var libraryBackground: some View {
///     if let name = ClassroomLibraryArtSlot.bookshelfLibrarySceneLandscape.resolvedName {
///         Image(name)
///             .resizable()
///             .scaledToFill()
///             .ignoresSafeArea()
///             .accessibilityHidden(true)
///     } else {
///         NovaPalette.classroomPaper.ignoresSafeArea()
///     }
/// }
/// ```
///
/// ## Contract
///
/// - **Live text stays in SwiftUI.** Every slot describes a
///   *background* / *decorative* asset only. Lesson titles, "NEW"
///   pills, completed counts, and locked-ribbon copy continue to
///   render as SwiftUI labels overlaid on the painted asset.
/// - **Missing assets degrade gracefully.** `resolvedName` returns
///   `nil` when no candidate is in the bundle, and call sites are
///   expected to fall back to a SwiftUI material. The lookup never
///   returns a string that doesn't resolve via `UIImage(named:)`.
/// - **Vault-canonical names win.** When both a canonical name and a
///   legacy alias resolve, the canonical name is preferred so a
///   half-finished migration doesn't silently regress to a placeholder.
public enum ClassroomLibraryArtSlot: String, CaseIterable {

    // MARK: - Library scene

    /// Full library / bookshelf scene, landscape. Used as the
    /// background for `ClassroomLessonLibraryView` on iPad landscape.
    case bookshelfLibrarySceneLandscape

    /// Full library / bookshelf scene, portrait. Same role as the
    /// landscape variant for iPad portrait.
    case bookshelfLibrarySceneLandscapePortrait

    /// Reusable single-shelf row plank used by
    /// `ClassroomLessonShelfSection` to anchor a row of book spines
    /// to a wooden shelf board.
    case bookshelfRow

    // MARK: - Book spines (per primary card type)

    /// Story lesson spine. No text baked in.
    case bookSpineStory

    /// Concept lesson spine. No text baked in.
    case bookSpineConcept

    /// Quiz lesson spine. No text baked in.
    case bookSpineQuiz

    /// Voice lesson spine. No text baked in.
    case bookSpineVoice

    /// Experiment lesson spine. No text baked in.
    case bookSpineExperiment

    /// Generic book cover/spine placeholder used when a lesson has
    /// no primary card type yet (`lesson.cards` empty before fetch
    /// completes), or its primary type does not have a dedicated
    /// painted spine.
    case bookCoverPlaceholder

    // MARK: - State badges

    /// New-lesson bookmark. Blank — the "NEW" copy is composed by
    /// SwiftUI on top.
    case lessonNewBookmark

    /// Completed-lesson sticker. Blank — the checkmark / count copy
    /// is composed by SwiftUI on top.
    case lessonCompletedSticker

    /// Locked / subscription state ribbon. No readable text in the
    /// asset; the locked-state label is composed by SwiftUI on top.
    case lessonLockedRibbon

    // MARK: - Resolution

    /// Imageset-name candidates for this slot, in preferred order.
    /// The first entry is the vault-canonical name; subsequent
    /// entries are legacy aliases that already ship in
    /// `Assets.xcassets` today, so a partial migration does not
    /// break production.
    public var candidates: [String] {
        switch self {
        // Library scene
        case .bookshelfLibrarySceneLandscape:
            return ["bookshelf_library_scene_45_landscape"]
        case .bookshelfLibrarySceneLandscapePortrait:
            return ["bookshelf_library_scene_45_portrait"]
        case .bookshelfRow:
            return ["bookshelf_row_45"]

        // Spines
        case .bookSpineStory:
            return ["book_spine_story_45"]
        case .bookSpineConcept:
            return ["book_spine_concept_45"]
        case .bookSpineQuiz:
            return ["book_spine_quiz_45"]
        case .bookSpineVoice:
            return ["book_spine_voice_45"]
        case .bookSpineExperiment:
            return ["book_spine_experiment_45"]
        case .bookCoverPlaceholder:
            return ["book_cover_placeholder_45"]

        // State badges
        case .lessonNewBookmark:
            return ["lesson_new_bookmark_45"]
        case .lessonCompletedSticker:
            return ["lesson_completed_sticker_45"]
        case .lessonLockedRibbon:
            return ["lesson_locked_ribbon_45"]
        }
    }

    /// First candidate that exists in the running app's asset
    /// catalog, or `nil` if none of the candidates resolve. Call
    /// sites should fall back to a SwiftUI material when this
    /// returns `nil`.
    public var resolvedName: String? {
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

    // MARK: - Helpers

    /// Resolve the appropriate spine slot for a lesson's primary
    /// card type. Falls back to `bookCoverPlaceholder` when the
    /// type is `nil` (lesson has no fetched cards yet) or maps to
    /// a card type without a dedicated painted spine (`.video`).
    public static func spine(for cardType: Card.CardType?) -> ClassroomLibraryArtSlot {
        guard let cardType else { return .bookCoverPlaceholder }
        switch cardType {
        case .story:      return .bookSpineStory
        case .concept:    return .bookSpineConcept
        case .quiz:       return .bookSpineQuiz
        case .voice:      return .bookSpineVoice
        case .experiment: return .bookSpineExperiment
        case .video:      return .bookCoverPlaceholder
        }
    }

    /// Library background variant for the current orientation.
    /// Designers can ship landscape first and portrait later; the
    /// portrait branch falls back to the landscape branch which
    /// itself falls back to a SwiftUI material via `resolvedName`.
    public static func libraryBackground(isPortrait: Bool) -> ClassroomLibraryArtSlot {
        isPortrait ? .bookshelfLibrarySceneLandscapePortrait : .bookshelfLibrarySceneLandscape
    }
}
