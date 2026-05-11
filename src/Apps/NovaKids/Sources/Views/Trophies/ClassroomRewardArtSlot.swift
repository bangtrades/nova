import SwiftUI
import UIKit

/// Centralized lookup for the NovaKids trophy-room and lesson-completion
/// reward art slots.
///
/// **Why this exists.** The trophy and completion surfaces are about to
/// receive a batch of generated 2.5D classroom reward art (see
/// `cortana-vault/projects/novai/novai--v2-beta-art-asset-list.md`).
/// Before this enum, neither `TrophyRoomView`, `BadgeView`,
/// `BadgeUnlockBurst`, nor `LessonCompleteCelebration` consumed any
/// painted asset — every visual was SwiftUI material — so a designer
/// dropping a vault-named PNG would have nowhere to wire it without
/// scattering string literals across four files.
///
/// `ClassroomRewardArtSlot` mirrors `LessonArtSlot`'s contract for the
/// reward surfaces: each case lists vault-canonical name first, legacy
/// alias second (none today; placeholders kept for forward-compat),
/// and `resolvedName` returns the first candidate that resolves via
/// `UIImage(named:)` or `nil` for SwiftUI fallback.
///
/// ## Contract
///
/// - **Live text stays in SwiftUI.** Each slot is a *background* /
///   *decorative* asset only. Trophy names, streak counts,
///   "You earned!" headlines, certificate copy — all rendered by
///   SwiftUI on top.
/// - **Missing assets degrade gracefully.** `resolvedName` returns
///   `nil` and the call site falls back to the existing classroom
///   SwiftUI material (chalkboard veil, paper rectangles, sun
///   stickers, etc.).
/// - **No PNGs are added in the slice that introduces this enum.**
///   The enum is the readiness contract; final art arrives in the
///   following import slice.
public enum ClassroomRewardArtSlot: String, CaseIterable {
    // MARK: - Trophy room scene

    /// Full-bleed trophy-room backdrop (landscape).
    case trophyRoomSceneLandscape

    /// Full-bleed trophy-room backdrop (portrait).
    case trophyRoomScenePortrait

    /// Wall-mounted trophy display case used as the shelf-panel
    /// background.
    case trophyCase

    /// Reusable shelf-row inside the trophy case.
    case trophyShelfRow

    /// Earned-badge disk (blank center; SwiftUI overlays the icon).
    case trophyBadgeDiskEarned

    /// Locked-badge disk (gentle silhouette).
    case trophyBadgeDiskLocked

    /// Empty achievement slot — inviting, not punitive.
    case trophyEmptySlot

    /// Badge detail certificate background.
    case trophyDetailCertificate

    /// Trophy unlock burst (sticker / confetti overlay).
    case trophyUnlockBurst

    /// Streak flame sticker — replaces the SF flame glyph when
    /// available.
    case streakFlameSticker

    // MARK: - Lesson completion celebration

    /// Background "stage" for the lesson-complete moment.
    case lessonCompletionStage

    /// Blank certificate paper used as the completion card backdrop.
    case lessonCompletionCertificate

    /// Trophy presentation frame around the earned hero image.
    case lessonCompletionTrophyFrame

    /// Confetti pieces overlay (transparent).
    case lessonCompletionConfettiPieces

    /// Dashy celebration pose shown on the completion stage.
    case dashyPoseCelebrating

    /// Painted "Continue" button object (replaces the sun capsule
    /// when available).
    case lessonCompletionContinueButton

    // MARK: - Resolution

    /// Imageset name candidates for this slot, vault-canonical first.
    /// Today none of the reward surfaces ship a legacy alias, so each
    /// list has a single canonical name. Legacy aliases can be added
    /// here without touching call sites if a partial migration ever
    /// requires it.
    public var candidates: [String] {
        switch self {
        case .trophyRoomSceneLandscape:        return ["trophy_room_scene_45_landscape"]
        case .trophyRoomScenePortrait:         return ["trophy_room_scene_45_portrait"]
        case .trophyCase:                      return ["trophy_case_45"]
        case .trophyShelfRow:                  return ["trophy_shelf_row_45"]
        case .trophyBadgeDiskEarned:           return ["trophy_badge_disk_earned_45"]
        case .trophyBadgeDiskLocked:           return ["trophy_badge_disk_locked_45"]
        case .trophyEmptySlot:                 return ["trophy_empty_slot_45"]
        case .trophyDetailCertificate:         return ["trophy_detail_certificate_45"]
        case .trophyUnlockBurst:               return ["trophy_unlock_burst_45"]
        case .streakFlameSticker:              return ["streak_flame_sticker_45"]
        case .lessonCompletionStage:           return ["lesson_completion_stage_45"]
        case .lessonCompletionCertificate:     return ["lesson_completion_certificate_45"]
        case .lessonCompletionTrophyFrame:     return ["lesson_completion_trophy_frame_45"]
        case .lessonCompletionConfettiPieces:  return ["lesson_completion_confetti_pieces_45"]
        case .dashyPoseCelebrating:            return ["dashy_pose_celebrating_45"]
        case .lessonCompletionContinueButton:  return ["lesson_completion_continue_button_object_45"]
        }
    }

    /// First candidate that exists in the running app's asset catalog,
    /// or `nil` if none of the candidates resolve. Call sites should
    /// fall back to a SwiftUI material when this returns `nil`.
    public var resolvedName: String? {
        Self.resolvedNameCache[self]
    }

    private static let resolvedNameCache: [ClassroomRewardArtSlot: String] = {
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

    /// True when at least one candidate resolves.
    public var hasAsset: Bool {
        resolvedName != nil
    }
}
