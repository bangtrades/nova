import XCTest
import CoreGraphics
@testable import NovaClassroom
import NovaCore

/// Deterministic coverage for `ClassroomSceneModel`'s object derivation.
///
/// V2-S1-02 / V2-S2-02 originally called for tests against per-card-type
/// derivation (story / concept / experiment / quiz / voice / video),
/// but the shipped derivation in `ClassroomSceneModel.swift` does **not**
/// branch on a lesson's first-card type — it derives objects from
///   1. presence of a current lesson (chalkboard state + destination),
///   2. trophy count (badge + accessibility label/hint),
///   3. a bulletin-board candidate selected from lessons by status,
///      not-current, and not-completed,
///   4. the age band's hotspot profile (4-5, 6-7, 8+ fallback).
/// These tests exercise the model as-is — see the task brief.
final class ClassroomSceneModelTests: XCTestCase {

    // MARK: - Fixtures

    private let userId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let pathId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    private func makeLesson(
        id: UUID = UUID(),
        pathId: UUID? = nil,
        title: String = "Lesson",
        status: Lesson.LessonStatus = .draft,
        sortOrder: Int = 0
    ) -> Lesson {
        Lesson(
            id: id,
            pathId: pathId,
            userId: userId,
            title: title,
            difficulty: 1,
            status: status,
            sortOrder: sortOrder
        )
    }

    private func makePath(id: UUID, title: String) -> LearningPath {
        LearningPath(
            id: id,
            userId: userId,
            title: title,
            sortOrder: 0,
            stage: .explorer
        )
    }

    private func object(
        _ model: ClassroomSceneModel,
        role: ClassroomObjectRole
    ) -> ClassroomObject? {
        model.objects.first { $0.role == role }
    }

    // MARK: - Empty / minimal state

    func testEmptyDataYieldsSixBaseObjectsAndNoBulletin() {
        let model = ClassroomSceneModel.home(
            currentLesson: nil,
            learningPaths: [],
            lessons: [],
            completedLessonIds: [],
            trophyCount: 0
        )

        XCTAssertEqual(model.objects.count, 6)
        XCTAssertTrue(model.objects.allSatisfy { $0.role != .bulletinBoard })

        let roles = Set(model.objects.map(\.role))
        XCTAssertEqual(roles, [
            .chalkboard, .bookshelf, .projectTable,
            .dashyDesk, .trophyShelf, .backpack,
        ])
    }

    func testDefaultIdAndAgeBand() {
        let model = ClassroomSceneModel.home(currentLessonId: nil)
        XCTAssertEqual(model.id, "nova-classroom-home")
        XCTAssertEqual(model.ageBand, .classroom45)
    }

    // MARK: - Chalkboard / current-lesson derivation

    func testChalkboardDisabledWhenNoCurrentLesson() {
        let model = ClassroomSceneModel.home(currentLessonId: nil)
        let chalk = object(model, role: .chalkboard)
        XCTAssertNotNil(chalk)
        XCTAssertEqual(chalk?.state, .disabled)
        XCTAssertEqual(chalk?.accessibilityLabel, "Chalkboard")
        XCTAssertEqual(chalk?.accessibilityHint, "No current lesson is ready yet.")
        if case .placeholder(let msg) = chalk?.destination {
            XCTAssertEqual(msg, "No lesson is ready yet.")
        } else {
            XCTFail("Expected placeholder destination, got \(String(describing: chalk?.destination))")
        }
    }

    func testChalkboardHighlightedWhenCurrentLessonPresent() {
        let lessonId = UUID()
        let model = ClassroomSceneModel.home(currentLessonId: lessonId)
        let chalk = object(model, role: .chalkboard)
        XCTAssertEqual(chalk?.state, .highlighted)
        XCTAssertEqual(chalk?.accessibilityLabel, "Chalkboard, continue lesson")
        XCTAssertEqual(chalk?.accessibilityHint, "Opens your current lesson.")
        XCTAssertEqual(chalk?.destination, .continueLesson(lessonId))
    }

    func testRichHomeApiRoutesCurrentLessonToChalkboard() {
        let current = makeLesson(title: "Current")
        let model = ClassroomSceneModel.home(
            currentLesson: current,
            learningPaths: [],
            lessons: [current]
        )
        XCTAssertEqual(object(model, role: .chalkboard)?.destination,
                       .continueLesson(current.id))
        XCTAssertEqual(object(model, role: .chalkboard)?.state, .highlighted)
    }

    // MARK: - Trophy count derivation

    func testTrophyCountZero() {
        let model = ClassroomSceneModel.home(currentLessonId: nil, trophyCount: 0)
        let shelf = object(model, role: .trophyShelf)
        XCTAssertEqual(shelf?.accessibilityLabel, "Trophy shelf")
        XCTAssertEqual(shelf?.accessibilityHint,
                       "Opens your trophies. None yet — finish a lesson to earn one.")
        XCTAssertNil(shelf?.badgeText)
    }

    func testTrophyCountOne() {
        let model = ClassroomSceneModel.home(currentLessonId: nil, trophyCount: 1)
        let shelf = object(model, role: .trophyShelf)
        XCTAssertEqual(shelf?.accessibilityLabel, "Trophy shelf, 1 trophy")
        XCTAssertEqual(shelf?.accessibilityHint, "Opens your trophies.")
        XCTAssertEqual(shelf?.badgeText, "1")
    }

    func testTrophyCountManyPluralizes() {
        let model = ClassroomSceneModel.home(currentLessonId: nil, trophyCount: 7)
        let shelf = object(model, role: .trophyShelf)
        XCTAssertEqual(shelf?.accessibilityLabel, "Trophy shelf, 7 trophies")
        XCTAssertEqual(shelf?.accessibilityHint, "Opens your trophies.")
        XCTAssertEqual(shelf?.badgeText, "7")
    }

    func testTrophyShelfDestinationIsTrophies() {
        let model = ClassroomSceneModel.home(currentLessonId: nil)
        XCTAssertEqual(object(model, role: .trophyShelf)?.destination, .trophies)
    }

    // MARK: - Disabled-placeholder objects

    func testProjectTableIsDisabledPlaceholder() {
        let model = ClassroomSceneModel.home(currentLessonId: UUID())
        let table = object(model, role: .projectTable)
        XCTAssertEqual(table?.state, .disabled)
        if case .placeholder(let msg) = table?.destination {
            XCTAssertEqual(msg, "Experiments will appear on the project table soon.")
        } else {
            XCTFail("Expected placeholder for project table")
        }
    }

    func testBackpackIsDisabledPlaceholder() {
        let model = ClassroomSceneModel.home(currentLessonId: UUID())
        let pack = object(model, role: .backpack)
        XCTAssertEqual(pack?.state, .disabled)
        if case .placeholder(let msg) = pack?.destination {
            XCTAssertEqual(msg, "Backpack tools are coming soon.")
        } else {
            XCTFail("Expected placeholder for backpack")
        }
    }

    func testBookshelfAndDashyDeskAreAvailable() {
        let model = ClassroomSceneModel.home(currentLessonId: nil)
        XCTAssertEqual(object(model, role: .bookshelf)?.state, .available)
        XCTAssertEqual(object(model, role: .bookshelf)?.destination, .lessonLibrary)
        XCTAssertEqual(object(model, role: .dashyDesk)?.state, .available)
        XCTAssertEqual(object(model, role: .dashyDesk)?.destination, .dashy)
    }

    // MARK: - Bulletin / "new mission" derivation

    func testBulletinAppearsForIncompleteNonCurrentLesson() {
        let next = makeLesson(pathId: pathId, title: "Next", status: .published)
        let model = ClassroomSceneModel.home(
            currentLesson: nil,
            learningPaths: [makePath(id: pathId, title: "Numbers")],
            lessons: [next],
            completedLessonIds: []
        )

        let bulletin = object(model, role: .bulletinBoard)
        XCTAssertNotNil(bulletin)
        XCTAssertEqual(bulletin?.state, .highlighted)
        XCTAssertEqual(bulletin?.destination, .lesson(next.id))
        XCTAssertEqual(bulletin?.id, "bulletin-board-\(next.id.uuidString)")
        XCTAssertEqual(bulletin?.accessibilityLabel, "Mission board, new lesson, Next")
        XCTAssertEqual(bulletin?.accessibilityHint,
                       "Opens this new mission from Numbers.")
        XCTAssertEqual(model.objects.count, 7)
    }

    func testBulletinPrefersPublishedOverDraftLesson() {
        let draft = makeLesson(title: "Draft", status: .draft, sortOrder: 0)
        let published = makeLesson(title: "Published", status: .published, sortOrder: 1)
        let model = ClassroomSceneModel.home(
            currentLesson: nil,
            learningPaths: [],
            lessons: [draft, published]
        )
        XCTAssertEqual(object(model, role: .bulletinBoard)?.destination,
                       .lesson(published.id))
    }

    func testBulletinFallsBackToNonPublishedWhenNoneArePublished() {
        let draft1 = makeLesson(title: "D1", status: .draft, sortOrder: 0)
        let draft2 = makeLesson(title: "D2", status: .review, sortOrder: 1)
        let model = ClassroomSceneModel.home(
            currentLesson: nil,
            learningPaths: [],
            lessons: [draft1, draft2]
        )
        XCTAssertEqual(object(model, role: .bulletinBoard)?.destination,
                       .lesson(draft1.id))
    }

    func testBulletinExcludesCurrentLesson() {
        let current = makeLesson(title: "Current", status: .published)
        let other = makeLesson(title: "Other", status: .published)
        let model = ClassroomSceneModel.home(
            currentLesson: current,
            learningPaths: [],
            lessons: [current, other]
        )
        let bulletin = object(model, role: .bulletinBoard)
        XCTAssertEqual(bulletin?.destination, .lesson(other.id))
    }

    func testBulletinExcludesCompletedLessons() {
        let done = makeLesson(title: "Done", status: .published, sortOrder: 0)
        let nextUp = makeLesson(title: "Next", status: .published, sortOrder: 1)
        let model = ClassroomSceneModel.home(
            currentLesson: nil,
            learningPaths: [],
            lessons: [done, nextUp],
            completedLessonIds: [done.id]
        )
        XCTAssertEqual(object(model, role: .bulletinBoard)?.destination,
                       .lesson(nextUp.id))
    }

    func testBulletinAbsentWhenAllLessonsCompletedOrCurrent() {
        let current = makeLesson(title: "Current", status: .published)
        let done = makeLesson(title: "Done", status: .published)
        let model = ClassroomSceneModel.home(
            currentLesson: current,
            learningPaths: [],
            lessons: [current, done],
            completedLessonIds: [done.id]
        )
        XCTAssertNil(object(model, role: .bulletinBoard))
        XCTAssertEqual(model.objects.count, 6)
    }

    func testBulletinAccessibilityHintWhenPathMissing() {
        let next = makeLesson(pathId: pathId, title: "Lonely", status: .published)
        let model = ClassroomSceneModel.home(
            currentLesson: nil,
            learningPaths: [], // path not present
            lessons: [next]
        )
        XCTAssertEqual(object(model, role: .bulletinBoard)?.accessibilityHint,
                       "Opens this new mission.")
    }

    func testBulletinAccessibilityHintWhenLessonHasNoPath() {
        let orphan = makeLesson(pathId: nil, title: "Orphan", status: .published)
        let model = ClassroomSceneModel.home(
            currentLesson: nil,
            learningPaths: [makePath(id: pathId, title: "Numbers")],
            lessons: [orphan]
        )
        XCTAssertEqual(object(model, role: .bulletinBoard)?.accessibilityHint,
                       "Opens this new mission.")
    }

    // MARK: - Active-prompt derivation

    func testActivePromptWhenNoLessonAndNoBulletin() {
        let model = ClassroomSceneModel.home(
            currentLesson: nil,
            learningPaths: [],
            lessons: []
        )
        XCTAssertEqual(model.activePrompt,
                       "Your classroom is ready. Ask a grown-up to add a lesson.")
    }

    func testActivePromptWithLessonNoBulletin() {
        let current = makeLesson(title: "Current", status: .published)
        let model = ClassroomSceneModel.home(
            currentLesson: current,
            learningPaths: [],
            lessons: [current]
        )
        XCTAssertEqual(model.activePrompt, "Tap the chalkboard to keep learning.")
    }

    func testActivePromptWithBulletinTakesPrecedence() {
        let current = makeLesson(title: "Current", status: .published)
        let next = makeLesson(title: "Next", status: .published)
        let model = ClassroomSceneModel.home(
            currentLesson: current,
            learningPaths: [],
            lessons: [current, next]
        )
        XCTAssertEqual(model.activePrompt, "A new mission is ready. Tap the board.")
    }

    func testLightHomeApiPromptWithLesson() {
        let model = ClassroomSceneModel.home(currentLessonId: UUID())
        XCTAssertEqual(model.activePrompt, "Tap the chalkboard to keep learning.")
    }

    func testLightHomeApiPromptWithoutLesson() {
        let model = ClassroomSceneModel.home(currentLessonId: nil)
        XCTAssertEqual(model.activePrompt,
                       "Your classroom is ready. Ask a grown-up to add a lesson.")
    }

    func testLightHomeApiDoesNotAddBulletinBoard() {
        let model = ClassroomSceneModel.home(currentLessonId: UUID(), trophyCount: 3)
        XCTAssertNil(object(model, role: .bulletinBoard))
        XCTAssertEqual(model.objects.count, 6)
    }

    // MARK: - Age band → hotspot profile derivation

    private func frames(_ model: ClassroomSceneModel) -> [ClassroomObjectRole: CGRect] {
        var result: [ClassroomObjectRole: CGRect] = [:]
        for obj in model.objects { result[obj.role] = obj.frame }
        return result
    }

    func testHotspotFramesForClassroom45() {
        let model = ClassroomSceneModel.home(currentLessonId: nil, ageBand: .classroom45)
        let f = frames(model)
        XCTAssertEqual(f[.chalkboard],
                       CGRect(x: 0.24, y: 0.07, width: 0.50, height: 0.36))
        XCTAssertEqual(f[.bookshelf],
                       CGRect(x: 0.03, y: 0.22, width: 0.21, height: 0.32))
        XCTAssertEqual(f[.projectTable],
                       CGRect(x: 0.28, y: 0.80, width: 0.42, height: 0.18))
        XCTAssertEqual(f[.dashyDesk],
                       CGRect(x: 0.71, y: 0.46, width: 0.27, height: 0.28))
        XCTAssertEqual(f[.trophyShelf],
                       CGRect(x: 0.76, y: 0.04, width: 0.20, height: 0.17))
        XCTAssertEqual(f[.backpack],
                       CGRect(x: 0.03, y: 0.56, width: 0.21, height: 0.20))
    }

    func testHotspotFramesForMakerLab67() {
        let model = ClassroomSceneModel.home(currentLessonId: nil, ageBand: .makerLab67)
        let f = frames(model)
        XCTAssertEqual(f[.chalkboard],
                       CGRect(x: 0.25, y: 0.08, width: 0.50, height: 0.34))
        XCTAssertEqual(f[.bookshelf],
                       CGRect(x: 0.03, y: 0.18, width: 0.21, height: 0.30))
        XCTAssertEqual(f[.dashyDesk],
                       CGRect(x: 0.71, y: 0.48, width: 0.27, height: 0.28))
        XCTAssertEqual(f[.trophyShelf],
                       CGRect(x: 0.76, y: 0.04, width: 0.20, height: 0.18))
        XCTAssertEqual(f[.backpack],
                       CGRect(x: 0.03, y: 0.50, width: 0.21, height: 0.22))
    }

    func testHotspotFramesForAIStudio8PlusFallBackToMakerLab() {
        let eight = ClassroomSceneModel.home(currentLessonId: nil, ageBand: .aiStudio8Plus)
        let seven = ClassroomSceneModel.home(currentLessonId: nil, ageBand: .makerLab67)
        XCTAssertEqual(frames(eight), frames(seven))
        XCTAssertEqual(eight.ageBand, .aiStudio8Plus)
    }

    func testBulletinFrameSwitchesWithAgeBand() {
        let lesson = makeLesson(title: "L", status: .published)
        let m45 = ClassroomSceneModel.home(
            currentLesson: nil, learningPaths: [], lessons: [lesson],
            ageBand: .classroom45
        )
        let m67 = ClassroomSceneModel.home(
            currentLesson: nil, learningPaths: [], lessons: [lesson],
            ageBand: .makerLab67
        )
        XCTAssertEqual(object(m45, role: .bulletinBoard)?.frame,
                       CGRect(x: 0.74, y: 0.23, width: 0.22, height: 0.22))
        XCTAssertEqual(object(m67, role: .bulletinBoard)?.frame,
                       CGRect(x: 0.74, y: 0.24, width: 0.22, height: 0.22))
    }

    // MARK: - ClassroomAgeBand mapping

    func testAgeBandForChildAgeBoundaries() {
        XCTAssertEqual(ClassroomAgeBand.forChildAge(3), .classroom45)
        XCTAssertEqual(ClassroomAgeBand.forChildAge(5), .classroom45)
        XCTAssertEqual(ClassroomAgeBand.forChildAge(6), .makerLab67)
        XCTAssertEqual(ClassroomAgeBand.forChildAge(7), .makerLab67)
        // 8+ rides the maker-lab band until the 8+ imageset ships.
        XCTAssertEqual(ClassroomAgeBand.forChildAge(8), .makerLab67)
        XCTAssertEqual(ClassroomAgeBand.forChildAge(12), .makerLab67)
    }

    func testAgeBandForNilProfileFallsBackToClassroom45() {
        XCTAssertEqual(ClassroomAgeBand.forChildProfile(nil), .classroom45)
    }

    // MARK: - Equality

    func testTwoEmptyHomesAreEqual() {
        let a = ClassroomSceneModel.home(currentLessonId: nil)
        let b = ClassroomSceneModel.home(currentLessonId: nil)
        XCTAssertEqual(a, b)
    }

    func testDifferentCurrentLessonsProduceDifferentModels() {
        let a = ClassroomSceneModel.home(currentLessonId: UUID())
        let b = ClassroomSceneModel.home(currentLessonId: UUID())
        XCTAssertNotEqual(a, b)
    }

    func testObjectOrderIsStable() {
        let model = ClassroomSceneModel.home(currentLessonId: UUID(), trophyCount: 4)
        let order = model.objects.map(\.role)
        XCTAssertEqual(order, [
            .chalkboard, .bookshelf, .projectTable,
            .dashyDesk, .trophyShelf, .backpack,
        ])
    }
}
