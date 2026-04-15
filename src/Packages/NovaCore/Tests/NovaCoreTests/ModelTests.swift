import XCTest
@testable import NovaCore

final class ModelTests: XCTestCase {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    override func setUp() {
        super.setUp()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - User Model Tests

    func testUserEncodingDecoding() throws {
        let user = User(
            id: UUID(),
            appleId: "001234.abcd1234",
            email: "parent@example.com",
            displayName: "Sarah"
        )

        let encoded = try encoder.encode(user)
        let decoded = try decoder.decode(User.self, from: encoded)

        XCTAssertEqual(user.id, decoded.id)
        XCTAssertEqual(user.displayName, decoded.displayName)
        XCTAssertEqual(user.email, decoded.email)
    }

    // MARK: - ChildProfile Tests

    func testChildProfileAgeCalculation() {
        let birthDate = Calendar.current.date(byAdding: .year, value: -5, to: Date())!
        let profile = ChildProfile(
            userId: UUID(),
            name: "Emma",
            birthDate: birthDate
        )

        XCTAssertEqual(profile.age, 5)
    }

    func testChildProfileStageDisplayNames() {
        XCTAssertEqual(ChildProfile.Stage.explorer.displayName, "Explorer")
        XCTAssertEqual(ChildProfile.Stage.thinker.displayName, "Thinker")
        XCTAssertEqual(ChildProfile.Stage.maker.displayName, "Maker")
        XCTAssertEqual(ChildProfile.Stage.creator.displayName, "Creator")
    }

    func testChildProfileStageRawValues() {
        XCTAssertEqual(ChildProfile.Stage.explorer.rawValue, 1)
        XCTAssertEqual(ChildProfile.Stage.thinker.rawValue, 2)
        XCTAssertEqual(ChildProfile.Stage.maker.rawValue, 3)
        XCTAssertEqual(ChildProfile.Stage.creator.rawValue, 4)
    }

    func testChildProfileEncodingDecoding() throws {
        let profile = ChildProfile(
            userId: UUID(),
            name: "Liam",
            birthDate: Date(),
            currentStage: 2
        )

        let encoded = try encoder.encode(profile)
        let decoded = try decoder.decode(ChildProfile.self, from: encoded)

        XCTAssertEqual(profile.name, decoded.name)
        XCTAssertEqual(profile.currentStage, decoded.currentStage)
    }

    // MARK: - Card Model Tests

    func testCardTypeRawValues() {
        let types: [Card.CardType] = [.story, .concept, .experiment, .quiz, .voice, .video]
        let expectedValues = ["story", "concept", "experiment", "quiz", "voice", "video"]

        for (type, expected) in zip(types, expectedValues) {
            XCTAssertEqual(type.rawValue, expected)
        }
    }

    func testCardTypeAllCases() {
        XCTAssertEqual(Card.CardType.allCases.count, 6)
    }

    func testCardContentEncodingDecoding() throws {
        var content = Card.CardContent(title: "Test Card")
        content.question = "What is AI?"
        content.options = [
            Card.CardContent.QuizOption(id: "1", text: "Artificial Intelligence"),
            Card.CardContent.QuizOption(id: "2", text: "Automated Integration"),
        ]
        content.correctOptionIndex = 0

        let encoded = try encoder.encode(content)
        let decoded = try decoder.decode(Card.CardContent.self, from: encoded)

        XCTAssertEqual(decoded.title, "Test Card")
        XCTAssertEqual(decoded.question, "What is AI?")
        XCTAssertEqual(decoded.options?.count, 2)
        XCTAssertEqual(decoded.correctOptionIndex, 0)
    }

    func testCardWithInteractionConfig() throws {
        let config = Card.InteractionConfig(
            maxAttempts: 3,
            showHintAfter: 1,
            successMessage: "Great job!",
            failureMessage: "Try again",
            hintMessage: "Think about..."
        )

        let encoded = try encoder.encode(config)
        let decoded = try decoder.decode(Card.InteractionConfig.self, from: encoded)

        XCTAssertEqual(decoded.maxAttempts, 3)
        XCTAssertEqual(decoded.showHintAfter, 1)
        XCTAssertEqual(decoded.successMessage, "Great job!")
    }

    // MARK: - Lesson Tests

    func testLessonStatusValues() {
        XCTAssertEqual(Lesson.LessonStatus.draft.rawValue, "draft")
        XCTAssertEqual(Lesson.LessonStatus.generating.rawValue, "generating")
        XCTAssertEqual(Lesson.LessonStatus.review.rawValue, "review")
        XCTAssertEqual(Lesson.LessonStatus.published.rawValue, "published")
    }

    func testLessonEncodingDecoding() throws {
        let lesson = Lesson(
            userId: UUID(),
            title: "Introduction to AI",
            description: "Learn the basics of AI",
            difficulty: 1,
            status: .published,
            sortOrder: 0
        )

        let encoded = try encoder.encode(lesson)
        let decoded = try decoder.decode(Lesson.self, from: encoded)

        XCTAssertEqual(lesson.title, decoded.title)
        XCTAssertEqual(lesson.status, decoded.status)
    }

    func testLessonWithAIAnalysis() throws {
        let analysis = Lesson.AIAnalysis(
            topic: "Machine Learning",
            suggestedStage: .maker,
            keyConceptsArray: ["Algorithms", "Data", "Training"],
            ageAppropriatenessScore: 0.85,
            flaggedContent: nil
        )

        let lesson = Lesson(
            userId: UUID(),
            title: "ML Basics",
            description: "Learn about machine learning",
            difficulty: 2,
            aiAnalysis: analysis,
            sortOrder: 0
        )

        let encoded = try encoder.encode(lesson)
        let decoded = try decoder.decode(Lesson.self, from: encoded)

        XCTAssertEqual(decoded.aiAnalysis?.topic, "Machine Learning")
        XCTAssertEqual(decoded.aiAnalysis?.suggestedStage, .maker)
        XCTAssertEqual(decoded.aiAnalysis?.ageAppropriatenessScore, 0.85)
    }

    // MARK: - Subscription Tests

    func testSubscriptionPlanValues() {
        XCTAssertEqual(Subscription.SubscriptionPlan.free.rawValue, "free")
        XCTAssertEqual(Subscription.SubscriptionPlan.pro.rawValue, "pro")
        XCTAssertEqual(Subscription.SubscriptionPlan.byok.rawValue, "byok")
    }

    func testSubscriptionStatusValues() {
        XCTAssertEqual(Subscription.SubscriptionStatus.active.rawValue, "active")
        XCTAssertEqual(Subscription.SubscriptionStatus.expired.rawValue, "expired")
        XCTAssertEqual(Subscription.SubscriptionStatus.cancelled.rawValue, "cancelled")
        XCTAssertEqual(Subscription.SubscriptionStatus.gracePeriod.rawValue, "gracePeriod")
    }

    func testSubscriptionIsActive() {
        let activeSub = Subscription(
            userId: UUID(),
            plan: .pro,
            status: .active
        )
        XCTAssertTrue(activeSub.isActive)

        let expiredSub = Subscription(
            userId: UUID(),
            plan: .pro,
            status: .expired
        )
        XCTAssertFalse(expiredSub.isActive)
    }

    // MARK: - Progress Tests

    func testCardInteractionEncodingDecoding() throws {
        let result = CardInteraction.InteractionResult(
            correct: true,
            choicesMade: ["option_1"],
            score: 0.95
        )

        let interaction = CardInteraction(
            sessionId: UUID(),
            cardId: UUID(),
            action: .completed,
            durationMs: 15000,
            result: result
        )

        let encoded = try encoder.encode(interaction)
        let decoded = try decoder.decode(CardInteraction.self, from: encoded)

        XCTAssertEqual(decoded.action, .completed)
        XCTAssertEqual(decoded.durationMs, 15000)
        XCTAssertEqual(decoded.result?.score, 0.95)
    }

    func testLearningSessionDuration() {
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(1800) // 30 minutes

        let session = LearningSession(
            childId: UUID(),
            startedAt: startDate,
            endedAt: endDate
        )

        XCTAssertEqual(session.durationSeconds, 1800)
    }

    // MARK: - Endpoint Tests

    func testEndpointPaths() {
        let userId = UUID()
        let childId = UUID()
        let lessonId = UUID()

        let profileEndpoint = Endpoint.getProfile()
        XCTAssertEqual(profileEndpoint.path, "/users/profile")
        XCTAssertEqual(profileEndpoint.method, .GET)

        let childrenEndpoint = Endpoint.getChildren()
        XCTAssertEqual(childrenEndpoint.path, "/children")

        let childEndpoint = Endpoint.deleteChild(id: childId)
        XCTAssertEqual(childEndpoint.path, "/children/\(childId.uuidString)")
        XCTAssertEqual(childEndpoint.method, .DELETE)

        let lessonEndpoint = Endpoint.getLesson(id: lessonId)
        XCTAssertEqual(lessonEndpoint.path, "/lessons/\(lessonId.uuidString)")

        let pathsEndpoint = Endpoint.getPaths()
        XCTAssertEqual(pathsEndpoint.path, "/paths")
    }

    func testEndpointAuthentication() {
        let publicEndpoint = Endpoint.signIn(appleToken: "token123")
        XCTAssertFalse(publicEndpoint.requiresAuth)

        let protectedEndpoint = Endpoint.getProfile()
        XCTAssertTrue(protectedEndpoint.requiresAuth)
    }

    // MARK: - Error Tests

    func testAPIErrorEquality() {
        let error1 = APIError.unauthorized
        let error2 = APIError.unauthorized
        XCTAssertEqual(error1, error2)

        let error3 = APIError.notFound
        XCTAssertNotEqual(error1, error3)

        let error4 = APIError.serverError(statusCode: 500, message: "Error")
        let error5 = APIError.serverError(statusCode: 500, message: "Error")
        XCTAssertEqual(error4, error5)
    }

    func testAPIErrorDescriptions() {
        XCTAssertNotNil(APIError.unauthorized.errorDescription)
        XCTAssertNotNil(APIError.notFound.errorDescription)
        XCTAssertNotNil(APIError.decodingError("test").errorDescription)
        XCTAssertNotNil(APIError.rateLimited(retryAfter: 60).errorDescription)
    }
}
