import XCTest
@testable import NovaClassroom

/// V2-S1-06 — runtime flag resolution. Locks the precedence contract
/// (environment > persisted default > shipped `true`) and the lenient
/// env parsing, so the rollback path can be trusted when a blocker
/// actually surfaces and someone reaches for it in a hurry.
final class ClassroomFeatureFlagsTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "ClassroomFeatureFlagsTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Shipped default

    func testDefaultsToTrueWithNoOverrides() {
        XCTAssertTrue(
            ClassroomFeatureFlags.classroomV2Enabled(environment: [:], defaults: defaults)
        )
    }

    // MARK: - Persisted default

    func testPersistedFalseDisablesClassroom() {
        defaults.set(false, forKey: ClassroomFeatureFlags.classroomV2DefaultsKey)
        XCTAssertFalse(
            ClassroomFeatureFlags.classroomV2Enabled(environment: [:], defaults: defaults)
        )
    }

    func testPersistedTrueEnablesClassroom() {
        defaults.set(true, forKey: ClassroomFeatureFlags.classroomV2DefaultsKey)
        XCTAssertTrue(
            ClassroomFeatureFlags.classroomV2Enabled(environment: [:], defaults: defaults)
        )
    }

    // MARK: - Environment override

    func testEnvironmentZeroDisablesClassroom() {
        XCTAssertFalse(
            ClassroomFeatureFlags.classroomV2Enabled(
                environment: ["NOVA_CLASSROOM_V2": "0"],
                defaults: defaults
            )
        )
    }

    func testEnvironmentBeatsPersistedDefault() {
        defaults.set(false, forKey: ClassroomFeatureFlags.classroomV2DefaultsKey)
        XCTAssertTrue(
            ClassroomFeatureFlags.classroomV2Enabled(
                environment: ["NOVA_CLASSROOM_V2": "1"],
                defaults: defaults
            )
        )
    }

    func testUnrecognizedEnvironmentValueFallsThrough() {
        // A typo'd override must not silently flip the Home — it falls
        // through to the next layer (here: persisted false).
        defaults.set(false, forKey: ClassroomFeatureFlags.classroomV2DefaultsKey)
        XCTAssertFalse(
            ClassroomFeatureFlags.classroomV2Enabled(
                environment: ["NOVA_CLASSROOM_V2": "banana"],
                defaults: defaults
            )
        )
    }

    // MARK: - Parser

    func testParseFlagAcceptedSpellings() {
        for truthy in ["1", "true", "YES", " on "] {
            XCTAssertEqual(ClassroomFeatureFlags.parseFlag(truthy), true, truthy)
        }
        for falsy in ["0", "false", "NO", " off "] {
            XCTAssertEqual(ClassroomFeatureFlags.parseFlag(falsy), false, falsy)
        }
        for junk in ["", "2", "enabled", "tru"] {
            XCTAssertNil(ClassroomFeatureFlags.parseFlag(junk), junk)
        }
    }
}
