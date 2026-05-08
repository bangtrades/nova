import Foundation
import NovaCore

extension Card {
    /// Kid-facing narration text for the current card.
    ///
    /// Generated lesson data is not perfectly consistent yet: some cards
    /// ship `voiceScript`, some only have type-specific content fields.
    /// Keep the fallback order centralized so every lesson-level audio
    /// control reads the same page text instead of silently doing nothing.
    var lessonReadAloudText: String? {
        switch type {
        case .story:
            return firstNonEmpty([
                voiceScript,
                content.narrativeText,
                content.bodyText,
                content.title
            ])

        case .concept:
            return firstNonEmpty([
                voiceScript,
                content.explanation,
                content.bodyText,
                content.title
            ])

        case .quiz:
            if let voiceScript = cleaned(voiceScript) {
                return voiceScript
            }

            guard let question = cleaned(content.question) else {
                return firstNonEmpty([content.bodyText, content.title])
            }

            let options = content.options?
                .map(\.text)
                .compactMap { cleaned($0) }
                .joined(separator: ". ")

            if let options, !options.isEmpty {
                return "Question. \(question). Choices are \(options)."
            }

            return "Question. \(question)."

        case .experiment:
            return firstNonEmpty([
                voiceScript,
                content.instructions,
                content.bodyText,
                content.title
            ])

        case .voice:
            return firstNonEmpty([
                voiceScript,
                content.promptText,
                content.bodyText,
                content.title
            ])

        case .video:
            return firstNonEmpty([
                voiceScript,
                content.bodyText,
                content.title
            ])
        }
    }

    private func firstNonEmpty(_ candidates: [String?]) -> String? {
        candidates.compactMap(cleaned).first
    }

    private func cleaned(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
