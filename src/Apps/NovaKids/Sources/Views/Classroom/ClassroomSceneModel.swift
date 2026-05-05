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
    /// Normalized frame in scene coordinates. Values are 0...1 and are scaled
    /// by `ClassroomSceneView` for portrait and landscape iPad layouts.
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
    static func home(currentLessonId: UUID?, trophyCount: Int = 0) -> ClassroomSceneModel {
        let hasLesson = currentLessonId != nil

        return ClassroomSceneModel(
            objects: baseHomeObjects(currentLessonId: currentLessonId, trophyCount: trophyCount),
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
        trophyCount: Int = 0
    ) -> ClassroomSceneModel {
        let currentLessonId = currentLesson?.id
        let hasLesson = currentLessonId != nil
        let bulletinLesson = bulletinLessonCandidate(
            currentLessonId: currentLessonId,
            lessons: lessons,
            completedLessonIds: completedLessonIds
        )

        var objects = baseHomeObjects(currentLessonId: currentLessonId, trophyCount: trophyCount)

        if let bulletinLesson {
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
                    frame: CGRect(x: 0.38, y: 0.42, width: 0.24, height: 0.16)
                )
            )
        }

        return ClassroomSceneModel(
            objects: objects,
            activePrompt: bulletinLesson != nil
                ? "A new mission is ready. Tap the board."
                : hasLesson
                    ? "Tap the chalkboard to keep learning."
                    : "Your classroom is ready. Ask a grown-up to add a lesson."
        )
    }

    private static func baseHomeObjects(
        currentLessonId: UUID?,
        trophyCount: Int = 0
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

        return [
            ClassroomObject(
                id: "chalkboard",
                role: .chalkboard,
                title: "Chalkboard",
                accessibilityLabel: hasLesson ? "Chalkboard, continue lesson" : "Chalkboard",
                accessibilityHint: hasLesson ? "Opens your current lesson." : "No current lesson is ready yet.",
                destination: currentLessonId.map(ClassroomDestination.continueLesson)
                    ?? .placeholder("No lesson is ready yet."),
                state: hasLesson ? .highlighted : .disabled,
                frame: CGRect(x: 0.21, y: 0.10, width: 0.42, height: 0.30)
            ),
            ClassroomObject(
                id: "bookshelf",
                role: .bookshelf,
                title: "Bookshelf",
                accessibilityLabel: "Bookshelf, lesson library",
                accessibilityHint: "Opens all lessons.",
                destination: .lessonLibrary,
                frame: CGRect(x: 0.05, y: 0.43, width: 0.26, height: 0.34)
            ),
            ClassroomObject(
                id: "project-table",
                role: .projectTable,
                title: "Project Table",
                accessibilityLabel: "Project table",
                accessibilityHint: "Experiments will appear here soon.",
                destination: .placeholder("Experiments will appear on the project table soon."),
                state: .disabled,
                frame: CGRect(x: 0.36, y: 0.61, width: 0.33, height: 0.25)
            ),
            ClassroomObject(
                id: "dashy-desk",
                role: .dashyDesk,
                title: "Dashy's Desk",
                accessibilityLabel: "Dashy's desk",
                accessibilityHint: "Opens Talk to Dashy.",
                destination: .dashy,
                frame: CGRect(x: 0.68, y: 0.42, width: 0.25, height: 0.29)
            ),
            ClassroomObject(
                id: "trophy-shelf",
                role: .trophyShelf,
                title: "Trophy Shelf",
                accessibilityLabel: trophyLabel,
                accessibilityHint: trophyHint,
                destination: .trophies,
                frame: CGRect(x: 0.67, y: 0.12, width: 0.27, height: 0.20),
                badgeText: trophyBadge
            ),
            ClassroomObject(
                id: "backpack",
                role: .backpack,
                title: "Backpack",
                accessibilityLabel: "Backpack and cubby",
                accessibilityHint: "Voice and profile tools will live here soon.",
                destination: .placeholder("Backpack tools are coming soon."),
                state: .disabled,
                frame: CGRect(x: 0.08, y: 0.79, width: 0.20, height: 0.16)
            ),
        ]
    }

    private static func bulletinLessonCandidate(
        currentLessonId: UUID?,
        lessons: [Lesson],
        completedLessonIds: Set<UUID>
    ) -> Lesson? {
        lessons.first { lesson in
            lesson.status == .published
                && lesson.id != currentLessonId
                && !completedLessonIds.contains(lesson.id)
        } ?? lessons.first { lesson in
            lesson.id != currentLessonId
                && !completedLessonIds.contains(lesson.id)
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
