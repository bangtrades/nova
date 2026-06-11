import Foundation

/// HTTP method for an endpoint request.
public enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case PATCH
    case DELETE
}

/// Represents an API endpoint with its path, method, and parameters.
public struct Endpoint {
    /// Path relative to the API base URL.
    public let path: String

    /// HTTP method for the request.
    public let method: HTTPMethod

    /// Request body (will be JSON encoded).
    public let body: Encodable?

    /// URL query items for the request.
    public let queryItems: [URLQueryItem]?

    /// Whether this endpoint requires authentication.
    public let requiresAuth: Bool

    /// Initializes a new Endpoint.
    /// - Parameters:
    ///   - path: Relative path (e.g., "/users/profile").
    ///   - method: HTTP method (defaults to GET).
    ///   - body: Request body.
    ///   - queryItems: Query parameters.
    ///   - requiresAuth: Whether authentication is required (defaults to true).
    public init(
        path: String,
        method: HTTPMethod = .GET,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil,
        requiresAuth: Bool = true
    ) {
        self.path = path
        self.method = method
        self.body = body
        self.queryItems = queryItems
        self.requiresAuth = requiresAuth
    }

    // MARK: - Auth Endpoints

    /// Sign in with Apple.
    ///
    /// Contract fix (Jun 10): the route is the backend's `/auth/apple`
    /// (the old `/auth/signin` never existed server-side), and the body
    /// carries the full credential set its zod schema requires. The
    /// snake_case wire keys produced by APIClient's encoder are accepted
    /// by the backend's tolerant-reader schema.
    public static func signIn(
        appleId: String,
        identityToken: String,
        displayName: String? = nil,
        email: String? = nil
    ) -> Endpoint {
        struct Body: Encodable {
            let identityToken: String
            let appleId: String
            let displayName: String?
            let email: String?
        }
        return Endpoint(
            path: "/auth/apple",
            method: .POST,
            body: Body(
                identityToken: identityToken,
                appleId: appleId,
                displayName: displayName,
                email: email
            ),
            requiresAuth: false
        )
    }

    /// Refresh access token using refresh token.
    public static func refreshToken(refreshToken: String) -> Endpoint {
        struct Body: Encodable {
            let refreshToken: String
        }
        return Endpoint(
            path: "/auth/refresh",
            method: .POST,
            body: Body(refreshToken: refreshToken),
            requiresAuth: false
        )
    }

    /// Development-only login (S14-VOX-02) — the backend mints a REAL
    /// token pair for its deterministic dev user. The backend answers
    /// 404 in production, so this is only useful against a dev server.
    public static func devBypass() -> Endpoint {
        return Endpoint(
            path: "/auth/dev-bypass",
            method: .POST,
            requiresAuth: false
        )
    }

    /// Delete user account.
    public static func deleteAccount() -> Endpoint {
        return Endpoint(path: "/auth/account", method: .DELETE)
    }

    // MARK: - User Endpoints

    /// Get current user profile.
    public static func getProfile() -> Endpoint {
        return Endpoint(path: "/users/profile")
    }

    /// Update user profile.
    public static func updateProfile(_ updates: [String: Any]) -> Endpoint {
        // Note: In real implementation, encode as proper Encodable struct
        return Endpoint(path: "/users/profile", method: .PATCH)
    }

    // MARK: - Child Profile Endpoints

    /// Get all child profiles for the user.
    public static func getChildren() -> Endpoint {
        return Endpoint(path: "/children")
    }

    /// Create a new child profile.
    public static func createChild(_ profile: ChildProfile) -> Endpoint {
        return Endpoint(path: "/children", method: .POST, body: profile)
    }

    /// Update a child profile.
    public static func updateChild(id: UUID, _ updates: ChildProfile) -> Endpoint {
        return Endpoint(path: "/children/\(id.uuidString)", method: .PATCH, body: updates)
    }

    /// Delete a child profile.
    public static func deleteChild(id: UUID) -> Endpoint {
        return Endpoint(path: "/children/\(id.uuidString)", method: .DELETE)
    }

    // MARK: - Lesson Endpoints

    /// Get lessons (optionally filtered by path and status).
    public static func getLessons(pathId: UUID? = nil, status: Lesson.LessonStatus? = nil) -> Endpoint {
        var queryItems: [URLQueryItem] = []
        if let pathId {
            queryItems.append(URLQueryItem(name: "path_id", value: pathId.uuidString))
        }
        if let status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        return Endpoint(
            path: "/lessons",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }

    /// Get a specific lesson.
    public static func getLesson(id: UUID) -> Endpoint {
        return Endpoint(path: "/lessons/\(id.uuidString)")
    }

    /// Create a new lesson.
    public static func createLesson(_ lesson: Lesson) -> Endpoint {
        return Endpoint(path: "/lessons", method: .POST, body: lesson)
    }

    /// Update a lesson.
    public static func updateLesson(id: UUID, _ updates: Lesson) -> Endpoint {
        return Endpoint(path: "/lessons/\(id.uuidString)", method: .PATCH, body: updates)
    }

    /// Publish a lesson by updating its status to published.
    public static func publishLesson(id: UUID) -> Endpoint {
        struct Body: Encodable {
            let status: String
        }
        return Endpoint(
            path: "/lessons/\(id.uuidString)",
            method: .PATCH,
            body: Body(status: "published")
        )
    }

    /// Delete a lesson.
    public static func deleteLesson(id: UUID) -> Endpoint {
        return Endpoint(path: "/lessons/\(id.uuidString)", method: .DELETE)
    }

    // MARK: - Card Endpoints

    /// Get cards for a lesson.
    public static func getCards(lessonId: UUID) -> Endpoint {
        return Endpoint(path: "/lessons/\(lessonId.uuidString)/cards")
    }

    /// Update a card.
    public static func updateCard(id: UUID, _ updates: Card) -> Endpoint {
        return Endpoint(path: "/cards/\(id.uuidString)", method: .PATCH, body: updates)
    }

    /// Reorder cards within a lesson.
    public static func reorderCards(lessonId: UUID, _ order: [UUID]) -> Endpoint {
        struct Body: Encodable {
            let order: [String]
        }
        return Endpoint(
            path: "/lessons/\(lessonId.uuidString)/cards/reorder",
            method: .POST,
            body: Body(order: order.map { $0.uuidString })
        )
    }

    // MARK: - Learning Path Endpoints

    /// Get all learning paths.
    public static func getPaths() -> Endpoint {
        return Endpoint(path: "/paths")
    }

    /// Create a new learning path.
    public static func createPath(_ path: LearningPath) -> Endpoint {
        return Endpoint(path: "/paths", method: .POST, body: path)
    }

    /// Update a learning path.
    public static func updatePath(id: UUID, _ updates: LearningPath) -> Endpoint {
        return Endpoint(path: "/paths/\(id.uuidString)", method: .PATCH, body: updates)
    }

    /// Delete a learning path.
    public static func deletePath(id: UUID) -> Endpoint {
        return Endpoint(path: "/paths/\(id.uuidString)", method: .DELETE)
    }

    /// Reorder paths.
    public static func reorderPaths(_ order: [UUID]) -> Endpoint {
        struct Body: Encodable {
            let order: [String]
        }
        return Endpoint(
            path: "/paths/reorder",
            method: .POST,
            body: Body(order: order.map { $0.uuidString })
        )
    }

    // MARK: - Progress Endpoints

    /// Sync progress interactions.
    ///
    /// Contract fix (Jun 10): the backend's `syncProgressSchema` requires
    /// a top-level `childId` — the old body omitted it, so every sync
    /// would have 400'd. `deviceId` is the schema's optional companion.
    public static func syncProgress(
        childId: UUID,
        deviceId: String? = nil,
        _ interactions: [CardInteraction]
    ) -> Endpoint {
        struct Body: Encodable {
            let childId: String
            let deviceId: String?
            let interactions: [CardInteraction]
        }
        return Endpoint(
            path: "/progress/sync",
            method: .POST,
            body: Body(
                childId: childId.uuidString.lowercased(),
                deviceId: deviceId,
                interactions: interactions
            )
        )
    }

    /// Get progress for a child.
    public static func getProgress(childId: UUID) -> Endpoint {
        return Endpoint(path: "/children/\(childId.uuidString)/progress")
    }

    /// Get all available badges.
    public static func getBadges() -> Endpoint {
        return Endpoint(path: "/badges")
    }

    /// Get badges earned by a child.
    public static func getEarnedBadges(childId: UUID) -> Endpoint {
        return Endpoint(path: "/children/\(childId.uuidString)/badges")
    }

    // MARK: - Content Pipeline Endpoints

    /// Ingest a URL for lesson generation.
    public static func ingestURL(_ urlString: String) -> Endpoint {
        struct Body: Encodable {
            let url: String
        }
        return Endpoint(
            path: "/pipeline/ingest",
            method: .POST,
            body: Body(url: urlString)
        )
    }

    /// Get status of an ingest job.
    public static func getIngestStatus(id: UUID) -> Endpoint {
        return Endpoint(path: "/pipeline/ingest/\(id.uuidString)/status")
    }

    /// Generate cards for a lesson from ingested content.
    ///
    /// Contract fix (Jun 10): the backend's `generateCardsSchema` takes
    /// camelCase `{ ingestId, pathId?, childId? }` — the old body's
    /// `ingest_id` key would never validate, and `stage` isn't part of
    /// the schema (the pipeline derives staging from the child profile
    /// when `childId` is supplied).
    public static func generateCardsFromIngest(
        ingestId: UUID,
        pathId: UUID? = nil,
        childId: UUID? = nil
    ) -> Endpoint {
        struct Body: Encodable {
            let ingestId: String
            let pathId: String?
            let childId: String?
        }
        return Endpoint(
            path: "/pipeline/generate/cards",
            method: .POST,
            body: Body(
                ingestId: ingestId.uuidString.lowercased(),
                pathId: pathId?.uuidString.lowercased(),
                childId: childId?.uuidString.lowercased()
            )
        )
    }

    /// Generate assets (images, audio) for a lesson.
    ///
    /// Contract fix (Jun 10): the backend route is
    /// `POST /pipeline/assets/:lessonId` — the lesson id rides the path,
    /// no body needed (empty-body POSTs are tolerated since S14-VOX-03).
    public static func generateAssets(lessonId: UUID) -> Endpoint {
        return Endpoint(
            path: "/pipeline/assets/\(lessonId.uuidString)",
            method: .POST
        )
    }

    /// Generate lesson assets (TTS and images).
    ///
    /// Contract fix (Jun 10): the lesson id rides the path; the old
    /// redundant `lesson_id` body key was never read by the backend.
    public static func generateLessonAssets(lessonId: UUID) -> Endpoint {
        return Endpoint(
            path: "/pipeline/assets/\(lessonId.uuidString)",
            method: .POST
        )
    }

    /// Get the status of asset generation for a lesson.
    public static func getAssetStatus(lessonId: UUID) -> Endpoint {
        return Endpoint(path: "/pipeline/assets/\(lessonId.uuidString)/status")
    }

    // MARK: - Sync Endpoints

    /// Sync lessons and paths since a given timestamp.
    public static func sync(since: Date? = nil, limit: Int = 100) -> Endpoint {
        var queryItems: [URLQueryItem] = []

        if let since = since {
            let timestamp = Int(since.timeIntervalSince1970)
            queryItems.append(URLQueryItem(name: "since", value: String(timestamp)))
        }

        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))

        return Endpoint(
            path: "/sync",
            queryItems: queryItems
        )
    }

    // MARK: - OAuth Endpoints

    /// Connect an LLM provider.
    public static func connectProvider(code: String, provider: LLMProvider.LLMProviderType) -> Endpoint {
        struct Body: Encodable {
            let code: String
            let provider: String
        }
        return Endpoint(
            path: "/oauth/connect",
            method: .POST,
            body: Body(code: code, provider: provider.rawValue)
        )
    }

    /// Disconnect an LLM provider.
    public static func disconnectProvider(id: UUID) -> Endpoint {
        return Endpoint(path: "/oauth/providers/\(id.uuidString)", method: .DELETE)
    }

    /// Get connected providers.
    public static func getProviders() -> Endpoint {
        return Endpoint(path: "/oauth/providers")
    }

    // MARK: - Subscription Endpoints

    /// Get current subscription.
    public static func getSubscription() -> Endpoint {
        return Endpoint(path: "/subscription")
    }

    /// Verify App Store receipt.
    public static func verifyReceipt(_ receipt: String) -> Endpoint {
        struct Body: Encodable {
            let receipt: String
        }
        return Endpoint(
            path: "/subscription/verify-receipt",
            method: .POST,
            body: Body(receipt: receipt)
        )
    }

    // MARK: - Dashy Chat Endpoints

    /// Send a message to Dashy for AI response.
    ///
    /// Contract fix (Jun 10): the backend's `dashyMessageSchema` wants
    /// `{ childId, transcript, conversationHistory[{role: user|assistant,
    /// content}], providerId? }` — the old body sent `{ message, history,
    /// childAge }`, none of which the schema recognizes, so every chat
    /// turn would have 400'd. Callers must map their local "dashy" role
    /// to "assistant" before passing history.
    public static func dashyChat(
        childId: UUID,
        transcript: String,
        conversationHistory: [[String: String]] = [],
        providerId: String? = nil
    ) -> Endpoint {
        struct Body: Encodable {
            let childId: String
            let transcript: String
            let conversationHistory: [[String: String]]
            let providerId: String?
        }
        return Endpoint(
            path: "/dashy/chat",
            method: .POST,
            body: Body(
                childId: childId.uuidString.lowercased(),
                transcript: transcript,
                conversationHistory: conversationHistory,
                providerId: providerId
            ),
            requiresAuth: true
        )
    }

    // MARK: - Entitlement Endpoints

    /// Get current user's entitlements.
    public static func getEntitlements() -> Endpoint {
        return Endpoint(path: "/entitlements")
    }

    /// Check if a specific feature is entitled.
    public static func checkEntitlement(feature: String) -> Endpoint {
        return Endpoint(path: "/entitlements/check/\(feature)")
    }

    // MARK: - Analytics Endpoints

    /// Get analytics data for a child.
    public static func getChildAnalytics(childId: UUID) -> Endpoint {
        return Endpoint(path: "/analytics/\(childId.uuidString)")
    }

    /// Export child's data.
    public static func exportChildData(childId: UUID) -> Endpoint {
        return Endpoint(path: "/children/\(childId.uuidString)/export")
    }

    /// Delete all data for a child (GDPR).
    public static func deleteChildData(childId: UUID) -> Endpoint {
        return Endpoint(path: "/children/\(childId.uuidString)/data", method: .DELETE)
    }

    // MARK: - Sync Endpoints (Additional)

    /// Sync offline events when connectivity returns.
    public static func syncOfflineEvents(_ events: [[String: Any]]) -> Endpoint {
        struct Body: Encodable {
            let events: [[String: String]]
        }
        return Endpoint(
            path: "/sync/events",
            method: .POST,
            body: Body(events: []),  // Note: events need proper encoding
            requiresAuth: true
        )
    }
}
