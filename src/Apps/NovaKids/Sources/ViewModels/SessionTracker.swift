import Foundation
import UIKit
import NovaCore
import NovaStorage

/// Tracks learning session interactions for progress reporting.
///
/// Records when children view cards, complete interactions, and submit responses.
/// Buffers interactions locally and syncs them to the backend via OfflineSyncQueue.
@MainActor
public class SessionTracker: ObservableObject {
    /// The current learning session.
    @Published public var currentSession: LearningSession?

    /// Buffered interactions awaiting sync.
    @Published public var pendingInteractions: [CardInteraction] = []

    /// The offline sync queue for storing interactions.
    private let syncQueue: OfflineSyncQueue

    /// Start time of current card view.
    private var cardViewStartTime: Date?

    /// Initialize a new SessionTracker.
    /// - Parameters:
    ///   - syncQueue: The offline sync queue for storing interactions.
    public init(syncQueue: OfflineSyncQueue) {
        self.syncQueue = syncQueue
    }

    // MARK: - Session Management

    /// Starts a new learning session for a child and lesson.
    ///
    /// - Parameters:
    ///   - childId: The ID of the child.
    ///   - lessonId: The ID of the lesson being studied.
    public func startSession(childId: String, lessonId: String) {
        let session = LearningSession(
            id: UUID(),
            childId: UUID(uuidString: childId) ?? UUID(),
            startedAt: Date(),
            deviceId: UIDevice.current.identifierForVendor?.uuidString
        )

        self.currentSession = session
        pendingInteractions.removeAll()
    }

    /// Ends the current learning session.
    ///
    /// - Returns: A session report with summary statistics.
    public func endSession() -> SessionReport? {
        guard let session = currentSession else { return nil }

        var endedSession = session
        endedSession.endedAt = Date()

        let report = SessionReport(
            sessionId: session.id,
            childId: session.childId,
            duration: endedSession.durationSeconds ?? 0,
            cardsViewed: Set(pendingInteractions.map { $0.cardId }).count,
            interactionsCount: pendingInteractions.count,
            completedCount: pendingInteractions.filter { $0.action == .completed }.count,
            skippedCount: pendingInteractions.filter { $0.action == .skipped }.count
        )

        currentSession = nil

        return report
    }

    // MARK: - Interaction Tracking

    /// Tracks that a card was viewed.
    ///
    /// - Parameters:
    ///   - cardId: The ID of the card.
    public func trackCardView(cardId: String) {
        guard let session = currentSession else { return }

        cardViewStartTime = Date()

        let interaction = CardInteraction(
            sessionId: session.id,
            cardId: UUID(uuidString: cardId) ?? UUID(),
            action: .viewed,
            durationMs: 0,
            timestamp: Date()
        )

        addInteraction(interaction)
    }

    /// Tracks a generic interaction on a card.
    ///
    /// - Parameters:
    ///   - cardId: The ID of the card.
    ///   - type: The type of interaction.
    ///   - result: Optional result data (e.g., quiz answer).
    public func trackInteraction(
        cardId: String,
        type: CardInteraction.InteractionAction,
        result: CardInteraction.InteractionResult? = nil
    ) {
        guard let session = currentSession else { return }

        let duration = cardViewStartTime.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0

        let interaction = CardInteraction(
            sessionId: session.id,
            cardId: UUID(uuidString: cardId) ?? UUID(),
            action: type,
            durationMs: duration,
            result: result,
            timestamp: Date()
        )

        addInteraction(interaction)

        if type == .completed || type == .skipped {
            cardViewStartTime = nil
        }
    }

    /// Tracks a voice recording interaction.
    ///
    /// - Parameters:
    ///   - cardId: The ID of the card.
    ///   - transcript: The transcribed text from voice input.
    ///   - isCorrect: Whether the response was correct.
    public func trackVoiceInteraction(
        cardId: String,
        transcript: String,
        isCorrect: Bool
    ) {
        guard let session = currentSession else { return }

        let duration = cardViewStartTime.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0

        let interaction = CardInteraction(
            sessionId: session.id,
            cardId: UUID(uuidString: cardId) ?? UUID(),
            action: .voiceInput,
            durationMs: duration,
            voiceTranscript: transcript,
            result: CardInteraction.InteractionResult(correct: isCorrect),
            timestamp: Date()
        )

        addInteraction(interaction)
        cardViewStartTime = nil
    }

    /// Tracks an experiment interaction (drag-and-drop, etc.).
    ///
    /// - Parameters:
    ///   - cardId: The ID of the card.
    ///   - choices: Array of choices made.
    ///   - isCorrect: Whether the experiment was completed correctly.
    public func trackExperimentInteraction(
        cardId: String,
        choices: [String],
        isCorrect: Bool
    ) {
        guard let session = currentSession else { return }

        let duration = cardViewStartTime.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0

        let interaction = CardInteraction(
            sessionId: session.id,
            cardId: UUID(uuidString: cardId) ?? UUID(),
            action: .experimentAttempt,
            durationMs: duration,
            result: CardInteraction.InteractionResult(
                correct: isCorrect,
                choicesMade: choices
            ),
            timestamp: Date()
        )

        addInteraction(interaction)
        cardViewStartTime = nil
    }

    // MARK: - Syncing

    /// Syncs pending interactions to the offline queue.
    ///
    /// Buffers interactions locally for batch sync to the server.
    public func syncInteractions() throws {
        if !pendingInteractions.isEmpty {
            try syncQueue.enqueue(pendingInteractions)
            pendingInteractions.removeAll()
        }
    }

    /// Gets all pending interactions.
    public func getPendingInteractions() -> [CardInteraction] {
        return pendingInteractions
    }

    // MARK: - Private Methods

    private func addInteraction(_ interaction: CardInteraction) {
        pendingInteractions.append(interaction)

        // Batch sync every 10 interactions
        if pendingInteractions.count >= 10 {
            try? syncInteractions()
        }
    }
}

/// Summary of a learning session.
public struct SessionReport {
    /// Unique session identifier.
    public let sessionId: UUID

    /// ID of the child who participated.
    public let childId: UUID

    /// Total session duration in seconds.
    public let duration: TimeInterval

    /// Number of unique cards viewed.
    public let cardsViewed: Int

    /// Total number of interactions.
    public let interactionsCount: Int

    /// Number of completed interactions.
    public let completedCount: Int

    /// Number of skipped interactions.
    public let skippedCount: Int

    /// Computed completion rate.
    public var completionRate: Double {
        guard interactionsCount > 0 else { return 0 }
        return Double(completedCount) / Double(interactionsCount)
    }
}
