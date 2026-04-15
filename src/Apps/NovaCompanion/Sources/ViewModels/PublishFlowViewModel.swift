import Foundation
import NovaCore

/// ViewModel for the publish flow with checklist validation and asset generation.
public class PublishFlowViewModel: ObservableObject {
    // MARK: - State

    @Published var publishState: PublishState = .idle
    @Published var checklist: [ChecklistItem] = []
    @Published var assetProgress: Float = 0.0
    @Published var errorMessage: String?

    enum PublishState {
        case idle
        case checking
        case readyToPublish
        case generatingAssets
        case publishing
        case completed
        case error(String)
    }

    struct ChecklistItem: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        var status: Status

        enum Status {
            case passed
            case warning
            case failed
        }

        var icon: String {
            switch status {
            case .passed:
                return "checkmark.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .failed:
                return "xmark.circle.fill"
            }
        }

        var color: String {
            switch status {
            case .passed:
                return "green"
            case .warning:
                return "orange"
            case .failed:
                return "red"
            }
        }
    }

    let lesson: Lesson

    init(lesson: Lesson) {
        self.lesson = lesson
    }

    // MARK: - Public Methods

    /// Validates the lesson and builds the pre-publish checklist.
    func runChecklist() {
        publishState = .checking

        var items: [ChecklistItem] = []

        // Check 1: All cards have content
        let allCardsValid = lesson.cards?.allSatisfy { card in
            cardHasContent(card)
        } ?? false

        items.append(ChecklistItem(
            title: "Card Content",
            description: allCardsValid ? "All \(lesson.cards?.count ?? 0) cards have content" : "Some cards are missing content",
            status: allCardsValid ? .passed : .failed
        ))

        // Check 2: Voice scripts present
        let voiceScriptCount = lesson.cards?.filter { $0.voiceScript != nil && !$0.voiceScript!.isEmpty }.count ?? 0
        items.append(ChecklistItem(
            title: "Voice Narration",
            description: voiceScriptCount > 0 ?
                "\(voiceScriptCount) card(s) have voice scripts" :
                "No voice scripts recorded (optional)",
            status: voiceScriptCount > 0 ? .passed : .warning
        ))

        // Check 3: Images present
        let imageCount = lesson.cards?.filter { $0.imageURL != nil }.count ?? 0
        items.append(ChecklistItem(
            title: "Images",
            description: imageCount > 0 ?
                "\(imageCount) card(s) have images" :
                "No images uploaded (can be generated)",
            status: imageCount > 0 ? .passed : .warning
        ))

        // Check 4: Card order reviewed
        items.append(ChecklistItem(
            title: "Card Order",
            description: "Review the lesson flow in preview",
            status: .passed
        ))

        // Check 5: Lesson metadata
        let metadataValid = !lesson.title.isEmpty && !lesson.description.isEmpty
        items.append(ChecklistItem(
            title: "Lesson Details",
            description: metadataValid ? "Title and description set" : "Missing title or description",
            status: metadataValid ? .passed : .failed
        ))

        checklist = items

        // Determine if ready to publish
        let hasFailures = items.contains { $0.status == .failed }
        publishState = hasFailures ? .error("Some checklist items failed") : .readyToPublish
    }

    /// Generates assets (TTS audio and images) for the lesson.
    func generateAssets() async {
        publishState = .generatingAssets
        assetProgress = 0.0

        // Simulate asset generation
        // In a real implementation, this would call the backend API
        for i in 0..<10 {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            assetProgress = Float(i + 1) / 10.0
        }

        // After asset generation, move to publishing
        assetProgress = 1.0
    }

    /// Publishes the lesson to the backend.
    func publish() async {
        publishState = .publishing

        // Simulate publish request
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        publishState = .completed
    }

    /// Generates assets and then publishes.
    func publishWithAssets() async {
        await generateAssets()
        await publish()
    }

    // MARK: - Private Methods

    private func cardHasContent(_ card: Card) -> Bool {
        switch card.type {
        case .story:
            return (card.content.title != nil && !card.content.title!.isEmpty) &&
                   (card.content.narrativeText != nil && !card.content.narrativeText!.isEmpty)
        case .concept:
            return (card.content.title != nil && !card.content.title!.isEmpty) &&
                   (card.content.explanation != nil && !card.content.explanation!.isEmpty)
        case .experiment:
            return (card.content.title != nil && !card.content.title!.isEmpty) &&
                   (card.content.instructions != nil && !card.content.instructions!.isEmpty)
        case .quiz:
            return (card.content.question != nil && !card.content.question!.isEmpty) &&
                   (card.content.options != nil && !card.content.options!.isEmpty)
        case .voice:
            return (card.content.promptText != nil && !card.content.promptText!.isEmpty)
        case .video:
            return (card.content.videoURL != nil)
        }
    }
}
