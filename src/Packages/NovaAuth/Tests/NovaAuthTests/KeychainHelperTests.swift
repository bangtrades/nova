import XCTest
@testable import NovaAuth

final class KeychainHelperTests: XCTestCase {
    var keychain: KeychainHelper!
    let testKey = "test.nova.key"
    let testData = "test data".data(using: .utf8)!

    override func setUp() {
        super.setUp()
        keychain = KeychainHelper()

        // Clean up before each test
        try? keychain.delete(key: testKey)
    }

    override func tearDown() {
        // Clean up after each test
        try? keychain.delete(key: testKey)
        super.tearDown()
    }

    func testSaveAndLoad() throws {
        // Save data
        try keychain.save(key: testKey, data: testData)

        // Load data
        let loadedData = keychain.load(key: testKey)

        XCTAssertEqual(loadedData, testData)
    }

    func testLoadNonexistentKey() {
        let nonexistentData = keychain.load(key: "nonexistent.key")
        XCTAssertNil(nonexistentData)
    }

    func testDelete() throws {
        // Save data
        try keychain.save(key: testKey, data: testData)

        // Verify it's saved
        XCTAssertNotNil(keychain.load(key: testKey))

        // Delete it
        try keychain.delete(key: testKey)

        // Verify it's deleted
        XCTAssertNil(keychain.load(key: testKey))
    }

    func testDeleteNonexistentKeyDoesNotThrow() {
        // Should not throw even if key doesn't exist
        XCTAssertNoThrow {
            try keychain.delete(key: "nonexistent.key")
        }
    }

    func testUpdateExistingKey() throws {
        // Save initial data
        try keychain.save(key: testKey, data: testData)

        // Save new data with same key
        let newData = "updated data".data(using: .utf8)!
        try keychain.save(key: testKey, data: newData)

        // Verify updated data
        let loadedData = keychain.load(key: testKey)
        XCTAssertEqual(loadedData, newData)
    }

    func testMultipleKeys() throws {
        let key1 = "test.key1"
        let key2 = "test.key2"
        let data1 = "data1".data(using: .utf8)!
        let data2 = "data2".data(using: .utf8)!

        // Save both
        try keychain.save(key: key1, data: data1)
        try keychain.save(key: key2, data: data2)

        // Load both
        XCTAssertEqual(keychain.load(key: key1), data1)
        XCTAssertEqual(keychain.load(key: key2), data2)

        // Clean up
        try keychain.delete(key: key1)
        try keychain.delete(key: key2)
    }
}

extension KeychainHelperTests {
    func XCTAssertNoThrow(
        _ expression: @autoclosure () throws -> Void,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try expression()
        } catch {
            XCTFail("Expected no error, but got: \(error)", file: file, line: line)
        }
    }
}
