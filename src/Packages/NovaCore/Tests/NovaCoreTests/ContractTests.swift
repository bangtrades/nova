import XCTest
@testable import NovaCore

/// iOS ↔ backend wire-contract tests.
///
/// **Why this file exists.** Across S12–S14 the codebase accumulated at
/// least five battle-scar fixes for one recurring defect: the iOS JSON
/// decoder is stricter than what the Nova backend serializer actually
/// emits. ISO-8601 fractional seconds, uppercase UUIDs, `correctIndex`
/// vs `correctOptionIndex`, nullable `description`/`pathId` — each shipped
/// to a real device before anyone noticed, because nothing tested the
/// seam. The pre-existing `ModelTests` gives false confidence: it builds
/// its *own* `JSONDecoder` with a strict `.iso8601` strategy and round-
/// trips through its *own* encoder, so it never sees a real backend
/// payload and never catches drift.
///
/// **What this file does.** It decodes *recorded real backend responses*
/// (captured from the live Fastify server in May 2026 — see fixture
/// comments) through `APIClient.makeJSONDecoder()` — the exact decoder
/// the live app uses. If the backend changes a field name, a nullability,
/// or a date format, or if someone "simplifies" the production decoder,
/// one of these tests goes red *here*, in CI, instead of on bang's iPad.
///
/// **Maintenance.** When a backend list/detail endpoint changes shape,
/// re-capture its response with `curl … | jq` and update the matching
/// fixture below. The fixtures are intentionally inline (not separate
/// resource files) so a NovaCore SPM test run needs no bundle plumbing.
final class ContractTests: XCTestCase {

    /// The exact decoder the production `APIClient` uses for every
    /// backend response. Built via the shared factory — see
    /// `APIClient.makeJSONDecoder()`.
    private let decoder = APIClient.makeJSONDecoder()

    /// UTC Gregorian calendar — used to assert decoded `Date` values
    /// landed on the correct instant without epoch hand-arithmetic.
    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    // MARK: - Fixtures
    //
    // Recorded verbatim from the live backend, May 2026. Field names,
    // null patterns, date formats, and extra keys (`cardCount`,
    // `lessonCount`, `total`) all reflect what Prisma + Fastify actually
    // put on the wire — NOT what the iOS models wish were there.

    /// `GET /api/v1/lessons` — two records. Record 1 is a published
    /// lesson with millisecond-precision dates (the Prisma default) and
    /// the extra `cardCount` aggregate. Record 2 is a draft with every
    /// nullable field null (`pathId`, `description`, `publishedAt`,
    /// `sourceUrl`) and a date *without* fractional seconds — exercising
    /// the decoder's plain-ISO fallback path.
    private let lessonsJSON = """
    {
      "data": [
        {
          "id": "8a72d094-6e75-4d3b-bd2b-6235473b75fc",
          "userId": "7d8ecc5b-1af2-45a3-9a15-630cfa7a0623",
          "pathId": "d168406d-7db1-496e-b577-2ac74206a9fa",
          "title": "Sky - Simple English Wikipedia, the free encyclopedia",
          "description": "The sky is what we see when we look up outside.",
          "thumbnailUrl": null,
          "difficulty": 1,
          "status": "published",
          "sortOrder": 0,
          "createdAt": "2026-04-24T02:26:24.746Z",
          "publishedAt": "2026-04-26T03:09:21.541Z",
          "sourceUrl": "https://simple.wikipedia.org/wiki/Sky",
          "cardCount": 7
        },
        {
          "id": "3bb36244-7c9b-4fe4-ad85-ccf24643e486",
          "userId": "7d8ecc5b-1af2-45a3-9a15-630cfa7a0623",
          "pathId": null,
          "title": "Rainbow - Simple English Wikipedia",
          "description": null,
          "thumbnailUrl": null,
          "difficulty": 1,
          "status": "draft",
          "sortOrder": 1,
          "createdAt": "2026-04-23T19:50:00Z",
          "publishedAt": null,
          "sourceUrl": null,
          "cardCount": 7
        }
      ],
      "total": 2,
      "page": 1,
      "limit": 100,
      "totalPages": 1
    }
    """

    /// `GET /api/v1/paths` — two records. `stage` arrives as a bare
    /// integer (decodes into the `ChildProfile.Stage` Int-enum).
    /// `description`/`color` are null on the first record; the extra
    /// `lessonCount` aggregate is present on both.
    private let pathsJSON = """
    {
      "data": [
        {
          "id": "8150c782-3046-4690-ac1d-ae1609f503f0",
          "userId": "7d8ecc5b-1af2-45a3-9a15-630cfa7a0623",
          "title": "Science stage 1",
          "description": null,
          "color": null,
          "icon": "🔬",
          "sortOrder": 0,
          "stage": 1,
          "isPremium": false,
          "createdAt": "2026-04-23T19:45:54.169Z",
          "updatedAt": "2026-04-23T19:45:54.169Z",
          "lessonCount": 5
        },
        {
          "id": "bf3ae84b-127f-4c11-8ed5-bb620cbdf11f",
          "userId": "7d8ecc5b-1af2-45a3-9a15-630cfa7a0623",
          "title": "Technology",
          "description": "Computers and how we use them",
          "color": "#e65100",
          "icon": "💻",
          "sortOrder": 1,
          "stage": 2,
          "isPremium": false,
          "createdAt": "2026-04-23T19:46:00.000Z",
          "updatedAt": "2026-04-23T19:46:00.000Z",
          "lessonCount": 2
        }
      ],
      "total": 2
    }
    """

    /// `GET /api/v1/lessons/:id/cards` — a story card and a quiz card.
    /// The quiz card's `content.correctIndex` is the field-name-drift
    /// regression lock: the backend ships `correctIndex`, the iOS model
    /// property is `correctOptionIndex` (mapped via an explicit
    /// `CodingKey`). The story card's `content` carries a `text` key
    /// that the iOS `CardContent` model does NOT declare — Codable must
    /// ignore it (the backend double-writes `text` as a legacy backfill).
    private let cardsJSON = """
    {
      "data": [
        {
          "id": "0cc0a79e-2810-43c7-afb6-3dd4bf249a8f",
          "lessonId": "8a72d094-6e75-4d3b-bd2b-6235473b75fc",
          "type": "story",
          "sortOrder": 0,
          "content": {
            "title": "The Sky",
            "narrativeText": "Look up! The sky is so big and blue.",
            "text": "Look up! The sky is so big and blue."
          },
          "voiceScript": "Look up! The sky is so big and blue.",
          "imageUrl": "http://localhost:3000/dev/assets/assets/8a72d094/images/0cc0a79e.png",
          "audioUrl": "http://localhost:3000/dev/assets/assets/8a72d094/audio/07d2d796.mp3",
          "interactionConfig": null,
          "createdAt": "2026-04-24T02:27:01.512Z"
        },
        {
          "id": "1c4a1914-e592-4eb2-b095-66fa3f8ed79f",
          "lessonId": "8a72d094-6e75-4d3b-bd2b-6235473b75fc",
          "type": "quiz",
          "sortOrder": 5,
          "content": {
            "title": "Sky Quiz",
            "question": "What color is the daytime sky?",
            "options": [
              { "id": "a", "text": "Blue" },
              { "id": "b", "text": "Green" }
            ],
            "correctIndex": 0
          },
          "voiceScript": null,
          "imageUrl": null,
          "audioUrl": null,
          "interactionConfig": null,
          "createdAt": "2026-04-24T02:27:30.000Z"
        }
      ],
      "total": 2
    }
    """

    // MARK: - GET /lessons

    /// The headline regression lock. If this fails, the iPad falls back
    /// to mock content (exactly the S13-12 production incident). Covers:
    /// the `{ data, … }` envelope, fractional-second + plain ISO dates,
    /// nullable `pathId`/`description`/`publishedAt`/`sourceUrl`, the
    /// `status` enum, and tolerance of the extra `cardCount` key.
    func testLessonsListDecodesFromRealBackendPayload() throws {
        let envelope = try decoder.decode(
            PaginatedResponse<Lesson>.self,
            from: Data(lessonsJSON.utf8)
        )
        XCTAssertEqual(envelope.data.count, 2, "Both lesson records should decode.")

        let published = envelope.data[0]
        XCTAssertEqual(published.title, "Sky - Simple English Wikipedia, the free encyclopedia")
        XCTAssertEqual(published.status, .published)
        XCTAssertNotNil(published.pathId, "Published lesson carries a pathId.")
        XCTAssertNotNil(published.publishedAt, "Published lesson carries publishedAt.")
        XCTAssertEqual(published.sourceURL?.absoluteString, "https://simple.wikipedia.org/wiki/Sky")

        // The fractional-second date must land on the correct instant —
        // 2026-04-24T02:26:24.746Z. This is the exact string that broke
        // decoding on a real device pre-S13-12.
        let created = utc.dateComponents([.year, .month, .day, .hour, .minute, .second], from: published.createdAt)
        XCTAssertEqual(created.year, 2026)
        XCTAssertEqual(created.month, 4)
        XCTAssertEqual(created.day, 24)
        XCTAssertEqual(created.hour, 2)
        XCTAssertEqual(created.minute, 26)
        XCTAssertEqual(created.second, 24)

        let draft = envelope.data[1]
        XCTAssertEqual(draft.status, .draft)
        XCTAssertNil(draft.pathId, "Orphaned draft has a null pathId.")
        XCTAssertNil(draft.description, "Draft can ship a null description.")
        XCTAssertNil(draft.publishedAt, "Unpublished lesson has a null publishedAt.")
        XCTAssertNil(draft.sourceURL, "Draft can ship a null sourceUrl.")
        // The draft's createdAt has NO fractional seconds — proves the
        // decoder's plain-ISO fallback path works.
        XCTAssertEqual(utc.component(.year, from: draft.createdAt), 2026)
    }

    // MARK: - GET /paths

    /// Locks the `LearningPath` contract: the `{ data, total }` envelope,
    /// the bare-integer `stage` decoding into `ChildProfile.Stage`,
    /// nullable `description`/`color`, and tolerance of `lessonCount`.
    func testPathsListDecodesFromRealBackendPayload() throws {
        let envelope = try decoder.decode(
            PaginatedResponse<LearningPath>.self,
            from: Data(pathsJSON.utf8)
        )
        XCTAssertEqual(envelope.data.count, 2)

        let science = envelope.data[0]
        XCTAssertEqual(science.title, "Science stage 1")
        XCTAssertEqual(science.stage, .explorer, "stage: 1 → .explorer")
        XCTAssertNil(science.description, "Path can ship a null description.")
        XCTAssertNil(science.color, "Path can ship a null color.")
        XCTAssertEqual(science.icon, "🔬")

        let technology = envelope.data[1]
        XCTAssertEqual(technology.stage, .thinker, "stage: 2 → .thinker")
        XCTAssertEqual(technology.color, "#e65100")
        XCTAssertEqual(utc.component(.year, from: technology.updatedAt), 2026)
    }

    // MARK: - GET /lessons/:id/cards

    /// Locks the `Card` contract — most importantly the quiz card's
    /// `correctIndex` → `correctOptionIndex` field-name map (a real
    /// S12-12 bug) and that an undeclared `content.text` key is ignored
    /// rather than fatal.
    func testCardsListDecodesFromRealBackendPayload() throws {
        let envelope = try decoder.decode(
            PaginatedResponse<Card>.self,
            from: Data(cardsJSON.utf8)
        )
        XCTAssertEqual(envelope.data.count, 2)

        let story = envelope.data[0]
        XCTAssertEqual(story.type, .story)
        XCTAssertEqual(story.content.narrativeText, "Look up! The sky is so big and blue.")
        XCTAssertNotNil(story.imageURL, "Story card carries an imageUrl.")
        XCTAssertEqual(utc.component(.year, from: story.createdAt), 2026)

        let quiz = envelope.data[1]
        XCTAssertEqual(quiz.type, .quiz)
        XCTAssertEqual(quiz.content.question, "What color is the daytime sky?")
        XCTAssertEqual(quiz.content.options?.count, 2)
        // The field-name-drift regression lock: wire `correctIndex` MUST
        // populate the iOS `correctOptionIndex` property. If it silently
        // nils out, QuizCardView's correctness check breaks.
        XCTAssertEqual(quiz.content.correctOptionIndex, 0,
                       "Wire `correctIndex` must map to `correctOptionIndex`.")
        XCTAssertNil(quiz.imageURL, "Quiz card can ship a null imageUrl.")
        XCTAssertNil(quiz.voiceScript, "Quiz card can ship a null voiceScript.")
    }

    // MARK: - Decoder-configuration guard

    /// Documents *why* `APIClient.makeJSONDecoder()` uses a custom date
    /// strategy. This builds a strict `.iso8601` decoder (Swift's
    /// built-in) and proves it genuinely throws on the real fractional-
    /// second payload. If a future refactor "simplifies" the production
    /// decoder back to `.iso8601`, `testLessonsListDecodesFromRealBackendPayload`
    /// above goes red — this test explains the failure to whoever reads it.
    ///
    /// Runtime caveat: newer Foundation (observed on macOS 26 hosts)
    /// accepts fractional seconds under strict `.iso8601`, so the trap
    /// only springs on the OS versions our users actually run. Skip —
    /// don't fail — where the runtime is lenient; the A/B test below
    /// still pins the production decoder either way.
    func testStrictISO8601StrategyRejectsRealBackendDates() throws {
        let strict = JSONDecoder()
        strict.keyDecodingStrategy = .convertFromSnakeCase
        strict.dateDecodingStrategy = .iso8601 // the trap — do NOT use in production

        if (try? strict.decode(PaginatedResponse<Lesson>.self, from: Data(lessonsJSON.utf8))) != nil {
            throw XCTSkip("This runtime's strict .iso8601 accepts fractional seconds; canary not applicable here.")
        }

        XCTAssertThrowsError(
            try strict.decode(PaginatedResponse<Lesson>.self, from: Data(lessonsJSON.utf8)),
            "Strict .iso8601 must reject Prisma's fractional-second dates — this is the bug the custom decoder fixes."
        )
    }

    /// Confirms the production decoder is the one that succeeds where the
    /// strict decoder fails — a direct A/B on the same payload.
    func testProductionDecoderSucceedsWhereStrictDecoderFails() {
        let payload = Data(lessonsJSON.utf8)
        XCTAssertNoThrow(
            try decoder.decode(PaginatedResponse<Lesson>.self, from: payload),
            "APIClient.makeJSONDecoder() must decode real backend payloads."
        )
    }
}
