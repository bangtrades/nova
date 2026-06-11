import CoreGraphics
import Foundation
import NovaCore

/// Age-band hook for future classroom variants. The first shell renders the
/// 4-5 classroom, but the model is ready for the maker-lab and studio variants
/// described in the v2 plan.
public enum ClassroomAgeBand: String, Equatable, CaseIterable {
    case classroom45
    case makerLab67
    case aiStudio8Plus
}

public extension ClassroomAgeBand {
    /// Map a child's age (in years) to the classroom variant that should
    /// render Home for them.
    ///
    /// - `age <= 5`: `.classroom45` — the preschool classroom that ships
    ///   in the asset catalog today.
    /// - `age 6...7`: `.makerLab67` — the maker-lab classroom that ships
    ///   alongside the 4-5 art.
    /// - `age >= 8`: **TODO** — should resolve to `.aiStudio8Plus` once
    ///   the 8+ AI-studio artwork lands in the asset catalog. Until then,
    ///   8+ profiles ride `.makerLab67` so they still see an illustrated
    ///   classroom rather than dropping back to the SwiftUI shape shell.
    static func forChildAge(_ age: Int) -> ClassroomAgeBand {
        if age <= 5 {
            return .classroom45
        }

        // TODO: Return `.aiStudio8Plus` for `age >= 8` once the 8+
        // imageset (`classroom_home_8plus_landscape` /
        // `classroom_home_8plus_portrait`) ships in
        // `Assets.xcassets`. Until then we keep 8+ on the maker-lab
        // variant so the kid still gets an illustrated scene.
        return .makerLab67
    }

    /// Convenience: resolve a `ChildProfile?` to an age band, defaulting
    /// to `.classroom45` when no profile is loaded yet (e.g. first launch
    /// before sign-in completes).
    static func forChildProfile(_ profile: ChildProfile?) -> ClassroomAgeBand {
        guard let profile else { return .classroom45 }
        return forChildAge(profile.age)
    }

    // MARK: - Developer override

    /// Environment-variable name that engineers set in their Xcode
    /// scheme to force a specific classroom age band on launch. There is
    /// no UI affordance for this; it is read once via `ProcessInfo` and
    /// is the single shared parser used by `HomeView` (to override the
    /// rendered scene) and `ClassroomAssetDebugHUD` (to flag the
    /// `ageBand` row as `(forced)`).
    ///
    /// Recognized values: `45`, `67`, `8plus`. Any other value — and the
    /// absence of the variable — leaves the classroom on the age band
    /// derived from the active child profile.
    static let developerOverrideEnvVar = "NOVA_CLASSROOM_FORCE_AGE_BAND"

    /// Resolved override, if any. Returns the parsed `ClassroomAgeBand`
    /// when a recognized value is set, or `nil` otherwise.
    ///
    /// In Release builds the override is intentionally **always
    /// disabled** — the function exists so call sites compile in both
    /// configurations, but the `#if DEBUG` gate guarantees a Release
    /// binary cannot read the env var even if it has been baked into
    /// the scheme by accident.
    static func developerForcedOverride() -> ClassroomAgeBand? {
        #if DEBUG
        guard let raw = ProcessInfo.processInfo.environment[developerOverrideEnvVar] else {
            return nil
        }
        switch raw {
        case "45":
            return .classroom45
        case "67":
            return .makerLab67
        case "8plus":
            return .aiStudio8Plus
        default:
            return nil
        }
        #else
        return nil
        #endif
    }

    /// True when the running process has a recognized override active.
    /// Used by `ClassroomAssetDebugHUD` to color the `ageBand` row and
    /// append `(forced)` to its value. Always `false` in Release.
    static var isDeveloperOverrideActive: Bool {
        developerForcedOverride() != nil
    }
}

public enum ClassroomObjectRole: String, Equatable, CaseIterable {
    case chalkboard
    case bookshelf
    case projectTable
    case dashyDesk
    case trophyShelf
    case backpack
    case bulletinBoard
    case generatedLesson
}

public enum ClassroomDestination: Hashable {
    case continueLesson(UUID)
    case lesson(UUID)
    case lessonLibrary
    case dashy
    case trophies
    case voicePicker
    case placeholder(String)
}

public enum ClassroomObjectState: Equatable {
    case available
    case highlighted
    case disabled
}

public struct ClassroomObject: Identifiable, Equatable {
    public let id: String
    public let role: ClassroomObjectRole
    public let title: String
    public let accessibilityLabel: String
    public let accessibilityHint: String
    public let destination: ClassroomDestination
    public let state: ClassroomObjectState
    /// Normalized **hotspot** rectangle in scene coordinates (0...1).
    ///
    /// This is **not** a drawing rectangle for the furniture itself — the
    /// classroom is rendered as a single illustrated 2.5D background image
    /// (see `docs/NOVA-V2-classroom-2.5d-art-contract.md`). This rect marks
    /// the tappable zone laid *on top of* that artwork at the screen
    /// coordinates where the corresponding object appears in the scene.
    ///
    /// Hotspots are intentionally generous so a 4-year-old can land them
    /// confidently without precision aiming, and are positioned to avoid
    /// the column of pixels above Dashy's desk where the speech bubble
    /// floats. `ClassroomSceneView` scales these into iPad portrait and
    /// landscape layouts.
    public let frame: CGRect
    /// Optional small text shown as a sticker/count badge on the rendered
    /// classroom object — used today by the trophy shelf to surface a kid's
    /// trophy count without needing to navigate to the trophy room.
    public let badgeText: String?

    public init(
        id: String,
        role: ClassroomObjectRole,
        title: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        destination: ClassroomDestination,
        state: ClassroomObjectState = .available,
        frame: CGRect,
        badgeText: String? = nil
    ) {
        self.id = id
        self.role = role
        self.title = title
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
        self.destination = destination
        self.state = state
        self.frame = frame
        self.badgeText = badgeText
    }
}

public struct ClassroomSceneModel: Identifiable, Equatable {
    public let id: String
    public let ageBand: ClassroomAgeBand
    public let objects: [ClassroomObject]
    public let activePrompt: String?

    public init(
        id: String = "nova-classroom-home",
        ageBand: ClassroomAgeBand = .classroom45,
        objects: [ClassroomObject],
        activePrompt: String? = nil
    ) {
        self.id = id
        self.ageBand = ageBand
        self.objects = objects
        self.activePrompt = activePrompt
    }
}

public extension ClassroomSceneModel {
    static func home(
        currentLessonId: UUID?,
        trophyCount: Int = 0,
        ageBand: ClassroomAgeBand = .classroom45
    ) -> ClassroomSceneModel {
        let hasLesson = currentLessonId != nil

        return ClassroomSceneModel(
            ageBand: ageBand,
            objects: baseHomeObjects(
                currentLessonId: currentLessonId,
                trophyCount: trophyCount,
                ageBand: ageBand
            ),
            activePrompt: hasLesson
                ? "Tap the chalkboard to keep learning."
                : "Your classroom is ready. Ask a grown-up to add a lesson."
        )
    }

    static func home(
        currentLesson: Lesson?,
        learningPaths: [LearningPath],
        lessons: [Lesson],
        completedLessonIds: Set<UUID> = [],
        trophyCount: Int = 0,
        ageBand: ClassroomAgeBand = .classroom45
    ) -> ClassroomSceneModel {
        let currentLessonId = currentLesson?.id
        let hasLesson = currentLessonId != nil
        let bulletinLesson = bulletinLessonCandidate(
            currentLessonId: currentLessonId,
            lessons: lessons,
            completedLessonIds: completedLessonIds
        )

        var objects = baseHomeObjects(
            currentLessonId: currentLessonId,
            trophyCount: trophyCount,
            ageBand: ageBand
        )

        if let bulletinLesson {
            // Mission Board — right wall, mid-height, immediately below
            // the trophy shelf. Cork-board look in the painted scene.
            // Frame supplied by the age-band hotspot profile so 6-7
            // tuning travels with the rest of the per-band offsets.
            let profile = HotspotProfile.profile(for: ageBand)
            objects.append(
                ClassroomObject(
                    id: "bulletin-board-\(bulletinLesson.id.uuidString)",
                    role: .bulletinBoard,
                    title: "Mission Board",
                    accessibilityLabel: "Mission board, new lesson, \(bulletinLesson.title)",
                    accessibilityHint: bulletinAccessibilityHint(
                        for: bulletinLesson,
                        learningPaths: learningPaths
                    ),
                    destination: .lesson(bulletinLesson.id),
                    state: .highlighted,
                    frame: profile.bulletinBoard
                )
            )
        }

        return ClassroomSceneModel(
            ageBand: ageBand,
            objects: objects,
            activePrompt: bulletinLesson != nil
                ? "A new mission is ready. Tap the board."
                : hasLesson
                    ? "Tap the chalkboard to keep learning."
                    : "Your classroom is ready. Ask a grown-up to add a lesson."
        )
    }

    /// Hotspot zones for the 2.5D illustrated classroom-home scene at child
    /// POV. The kid is standing just inside the doorway, looking into the
    /// room: front wall straight ahead, left wall receding to the left, right
    /// wall receding to the right, foreground floor sweeping toward the
    /// viewer.
    ///
    /// **Calibrated to the 4-5 illustrated art** that ships in the asset
    /// catalog (`classroom_home_45_landscape`, `classroom_home_45_portrait`).
    /// One unified set of normalized rectangles drives both orientations;
    /// the iPad portrait/landscape art shares the same general layout with
    /// only proportional scaling.
    ///
    /// Frame budget (normalized, x → right, y → down):
    /// ```
    /// ┌──────────────────────────────────────────────────────────────┐
    /// │                                          ┌──────┐            │
    /// │                                          │trophy│            │
    /// │   ┌──────┐    ┌─────────────────┐        │shelf │            │
    /// │   │book- │    │   CHALKBOARD    │        └──────┘            │
    /// │   │shelf │    │  (primary CTA)  │        ┌──────┐            │
    /// │   │      │    │                 │        │missn │            │
    /// │   └──────┘    └─────────────────┘        │board │            │
    /// │   ┌──────┐                               └──────┘            │
    /// │   │cubby │                               ┌────────┐          │
    /// │   │backpk│                               │  Dashy │          │
    /// │   └──────┘                               │  desk  │          │
    /// │                                          └────────┘          │
    /// │           ┌───────project-table──────┐                       │
    /// └──────────────────────────────────────────────────────────────┘
    /// ```
    /// All hotspots stay at least ~0.18 on the short side so a 4-year-old can
    /// land them confidently, and adjacent hotspots leave a 1–2% gap so
    /// neighboring objects do not steal taps from each other. Trophy shelf
    /// and mission board sit stacked on the right wall but are vertically
    /// separated to keep them distinct silhouettes.
    /// See `docs/NOVA-V2-classroom-2.5d-art-contract.md` for the matching
    /// art contract.
    private static func baseHomeObjects(
        currentLessonId: UUID?,
        trophyCount: Int = 0,
        ageBand: ClassroomAgeBand
    ) -> [ClassroomObject] {
        let hasLesson = currentLessonId != nil
        let trophyLabel: String = {
            switch trophyCount {
            case 0: return "Trophy shelf"
            case 1: return "Trophy shelf, 1 trophy"
            default: return "Trophy shelf, \(trophyCount) trophies"
            }
        }()
        let trophyHint = trophyCount > 0
            ? "Opens your trophies."
            : "Opens your trophies. None yet — finish a lesson to earn one."
        let trophyBadge: String? = trophyCount > 0 ? "\(trophyCount)" : nil

        let profile = HotspotProfile.profile(for: ageBand)

        return [
            // Chalkboard — front wall, centered, primary CTA. Dominant
            // tap zone for "continue learning". Frame supplied by the
            // age-band hotspot profile.
            ClassroomObject(
                id: "chalkboard",
                role: .chalkboard,
                title: "Chalkboard",
                accessibilityLabel: hasLesson ? "Chalkboard, continue lesson" : "Chalkboard",
                accessibilityHint: hasLesson ? "Opens your current lesson." : "No current lesson is ready yet.",
                destination: currentLessonId.map(ClassroomDestination.continueLesson)
                    ?? .placeholder("No lesson is ready yet."),
                state: hasLesson ? .highlighted : .disabled,
                frame: profile.chalkboard
            ),
            // Bookshelf — left wall. Tappable shelf zone (NOT the
            // decorative window above it).
            ClassroomObject(
                id: "bookshelf",
                role: .bookshelf,
                title: "Bookshelf",
                accessibilityLabel: "Bookshelf, lesson library",
                accessibilityHint: "Opens all lessons.",
                destination: .lessonLibrary,
                frame: profile.bookshelf
            ),
            // Project Table — foreground center-bottom desk surface.
            // Disabled placeholder reserved for the future experiments
            // tap zone.
            ClassroomObject(
                id: "project-table",
                role: .projectTable,
                title: "Project Table",
                accessibilityLabel: "Project table",
                accessibilityHint: "Experiments will appear here soon.",
                destination: .placeholder("Experiments will appear on the project table soon."),
                state: .disabled,
                frame: profile.projectTable
            ),
            // Dashy's Desk — right foreground (blue desk + yellow lamp
            // in the painted scene).
            ClassroomObject(
                id: "dashy-desk",
                role: .dashyDesk,
                title: "Dashy's Desk",
                accessibilityLabel: "Dashy's desk",
                accessibilityHint: "Opens Talk to Dashy.",
                destination: .dashy,
                frame: profile.dashyDesk
            ),
            // Trophy Shelf — right wall, upper. Small wooden shelf with
            // trophies in the painted scene.
            ClassroomObject(
                id: "trophy-shelf",
                role: .trophyShelf,
                title: "Trophy Shelf",
                accessibilityLabel: trophyLabel,
                accessibilityHint: trophyHint,
                destination: .trophies,
                frame: profile.trophyShelf,
                badgeText: trophyBadge
            ),
            // Backpack / Cubby — colored cubby crates under the
            // bookshelf in the painted scene. Disabled placeholder.
            ClassroomObject(
                id: "backpack",
                role: .backpack,
                title: "Backpack",
                accessibilityLabel: "Backpack and cubby",
                accessibilityHint: "Voice and profile tools will live here soon.",
                destination: .placeholder("Backpack tools are coming soon."),
                state: .disabled,
                frame: profile.backpack
            ),
        ]
    }

    /// Per-age-band hotspot profile.
    ///
    /// Each painted classroom variant in `Assets.xcassets` puts its
    /// furniture at slightly different proportions. The 4-5 preschool
    /// classroom and the 6-7 maker lab share a layout (chalkboard
    /// front-center, bookshelf left wall, trophy shelf top-right,
    /// mission board mid-right, Dashy desk right foreground, cubby
    /// crates under the bookshelf, kid's desk in the foreground) but
    /// the exact normalized rectangles drift by a few percent. Rather
    /// than picking one set of frames that compromises both, the model
    /// keeps a small, named profile per age band and looks one up at
    /// `baseHomeObjects` time.
    ///
    /// Adding a new age band is a one-call-site change — add a new
    /// `HotspotProfile` constant and a `case` in `profile(for:)`.
    private struct HotspotProfile {
        let chalkboard: CGRect
        let bookshelf: CGRect
        let projectTable: CGRect
        let dashyDesk: CGRect
        let trophyShelf: CGRect
        let backpack: CGRect
        let bulletinBoard: CGRect

        /// 4-5 preschool classroom — calibrated to
        /// `classroom_home_45_landscape` / `classroom_home_45_portrait`.
        static let classroom45 = HotspotProfile(
            chalkboard:    CGRect(x: 0.24, y: 0.07, width: 0.50, height: 0.36),
            bookshelf:     CGRect(x: 0.03, y: 0.22, width: 0.21, height: 0.32),
            projectTable:  CGRect(x: 0.28, y: 0.80, width: 0.42, height: 0.18),
            dashyDesk:     CGRect(x: 0.71, y: 0.46, width: 0.27, height: 0.28),
            trophyShelf:   CGRect(x: 0.76, y: 0.04, width: 0.20, height: 0.17),
            backpack:      CGRect(x: 0.03, y: 0.56, width: 0.21, height: 0.20),
            bulletinBoard: CGRect(x: 0.74, y: 0.23, width: 0.22, height: 0.22)
        )

        /// 6-7 maker lab — calibrated to
        /// `classroom_home_67_landscape` / `classroom_home_67_portrait`.
        ///
        /// Versus the 4-5 frames, the painted 6-7 scene shifts the
        /// bookshelf slightly higher (so the cubby crates underneath
        /// rise too), grows the trophy shelf a touch taller, and seats
        /// Dashy's desk one notch lower as the lamp+desk silhouette
        /// reads slightly heavier. The chalkboard is recentered by 1%
        /// to match the painted slate. Project Table and Bulletin Board
        /// stay near their 4-5 positions since the foreground desk and
        /// cork-board land at the same proportions in both paintings.
        static let makerLab67 = HotspotProfile(
            chalkboard:    CGRect(x: 0.25, y: 0.08, width: 0.50, height: 0.34),
            bookshelf:     CGRect(x: 0.03, y: 0.18, width: 0.21, height: 0.30),
            projectTable:  CGRect(x: 0.28, y: 0.80, width: 0.42, height: 0.18),
            dashyDesk:     CGRect(x: 0.71, y: 0.48, width: 0.27, height: 0.28),
            trophyShelf:   CGRect(x: 0.76, y: 0.04, width: 0.20, height: 0.18),
            backpack:      CGRect(x: 0.03, y: 0.50, width: 0.21, height: 0.22),
            bulletinBoard: CGRect(x: 0.74, y: 0.24, width: 0.22, height: 0.22)
        )

        static func profile(for ageBand: ClassroomAgeBand) -> HotspotProfile {
            switch ageBand {
            case .classroom45:
                return .classroom45
            case .makerLab67:
                return .makerLab67
            case .aiStudio8Plus:
                // 8+ AI-studio art is not yet in `Assets.xcassets`.
                // 8+ profiles ride the maker-lab variant today (see
                // `ClassroomAgeBand.forChildAge(_:)`), so reusing the
                // maker-lab hotspot frames keeps the rendered layout
                // consistent with the rendered artwork. Replace this
                // case with a dedicated `.aiStudio8Plus` profile when
                // the 8+ imageset lands.
                return .makerLab67
            }
        }
    }

    private static func bulletinLessonCandidate(
        currentLessonId: UUID?,
        lessons: [Lesson],
        completedLessonIds: Set<UUID>
    ) -> Lesson? {
        lessons.first { lesson in
            lesson.status == .published
                && lesson.id != currentLessonId
                && completedLessonIds.contains(lesson.id) == false
        } ?? lessons.first { lesson in
            lesson.id != currentLessonId
                && completedLessonIds.contains(lesson.id) == false
        }
    }

    private static func bulletinAccessibilityHint(
        for lesson: Lesson,
        learningPaths: [LearningPath]
    ) -> String {
        guard let path = learningPaths.first(where: { $0.id == lesson.pathId }) else {
            return "Opens this new mission."
        }

        return "Opens this new mission from \(path.title)."
    }
}
