import Foundation
import NovaCore

/// ViewModel for the URL intake view in the content pipeline.
///
/// Manages URL analysis, content scraping, and card generation for lessons
/// created from web content.
@MainActor
public class URLIntakeViewModel: ObservableObject {
    /// The URL string being analyzed.
    @Published public var urlString: String = ""

    /// Current state of the intake process.
    @Published public var state: IntakeState = .idle

    /// Analysis results after scraping.
    @Published public var analysis: ContentAnalysis?

    /// ID of the generated lesson (on success).
    @Published public var generatedLessonId: String?

    /// Error message (if any).
    @Published public var errorMessage: String?

    /// API router for making requests.
    private let apiRouter: APIRouting

    /// Initialize a new URLIntakeViewModel.
    /// - Parameters:
    ///   - apiRouter: The API router for making requests.
    public init(apiRouter: APIRouting) {
        self.apiRouter = apiRouter
    }

    // MARK: - Public Methods

    /// Analyzes a URL for content extraction.
    ///
    /// Calls the backend to scrape and analyze the URL content,
    /// returning topic, key concepts, and suggested learning stage.
    public func analyzeURL() async {
        guard !urlString.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a valid URL"
            return
        }

        state = .scraping
        errorMessage = nil

        do {
            let analysisResponse: ContentAnalysisResponse = try await apiRouter.request(
                .ingestURL(urlString)
            )

            self.analysis = ContentAnalysis(
                topic: analysisResponse.topic,
                keyConcepts: analysisResponse.key_concepts,
                suggestedStage: analysisResponse.suggested_stage,
                cardCount: analysisResponse.card_count,
                ingestId: analysisResponse.ingest_id
            )

            state = .analyzing

            // Brief pause for visual feedback
            try await Task.sleep(nanoseconds: 1_000_000_000)

            state = .ready
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            state = .error
        } catch {
            errorMessage = "Failed to analyze URL: \(error.localizedDescription)"
            state = .error
        }
    }

    /// Generates a lesson from the analyzed content.
    ///
    /// Creates lesson cards based on the ingested URL content.
    /// Updates state with generation progress.
    public func generateLesson() async {
        guard let analysis = analysis else {
            errorMessage = "No analysis available"
            return
        }

        state = .generating
        errorMessage = nil

        do {
            let generateResponse: GenerateResponse = try await apiRouter.request(
                .generateCardsFromIngest(
                    ingestId: UUID(uuidString: analysis.ingestId) ?? UUID()
                )
            )

            self.generatedLessonId = generateResponse.lesson_id
            state = .completed

            // Brief pause for visual feedback
            try await Task.sleep(nanoseconds: 500_000_000)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            state = .error
        } catch {
            errorMessage = "Failed to generate lesson: \(error.localizedDescription)"
            state = .error
        }
    }

    /// Resets the view to allow another URL intake.
    public func reset() {
        urlString = ""
        state = .idle
        analysis = nil
        generatedLessonId = nil
        errorMessage = nil
    }

    // MARK: - State

    /// States of the intake process.
    public enum IntakeState: Equatable {
        case idle               // No action yet
        case scraping           // Fetching and scraping URL
        case analyzing          // Processing content
        case ready              // Ready to generate
        case generating         // Creating lesson cards
        case completed          // Success
        case error              // Error occurred
    }
}

// MARK: - Response Models

/// Response from content analysis.
struct ContentAnalysisResponse: Decodable {
    /// Topic discovered in the content.
    let topic: String

    /// Key concepts extracted.
    let key_concepts: [String]

    /// Suggested learning stage.
    let suggested_stage: String

    /// Estimated number of cards.
    let card_count: Int

    /// ID for tracking the ingest job.
    let ingest_id: String
}

/// Analysis result from URL scraping.
public struct ContentAnalysis {
    /// Topic discovered in the content.
    public let topic: String

    /// Key concepts extracted.
    public let keyConcepts: [String]

    /// Suggested learning stage.
    public let suggestedStage: String

    /// Estimated number of cards.
    public let cardCount: Int

    /// Ingest ID for card generation.
    public let ingestId: String
}

/// Response from lesson generation.
struct GenerateResponse: Decodable {
    /// ID of the newly created lesson.
    let lesson_id: String

    /// Number of cards created.
    let cards_created: Int

    /// Status of the generation.
    let status: String
}
