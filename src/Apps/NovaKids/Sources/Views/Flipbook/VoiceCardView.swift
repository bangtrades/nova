import SwiftUI
import NovaCore
import NovaVoice
import UIKit

/// Voice interaction card — the kid hears Dashy's prompt, speaks their answer,
/// and Dashy reacts with a celebration or a soft-reset hint based on how the
/// transcript matches the whitelist.
///
/// ## Wire contract (S12-06 voice-persona skill)
///
/// The backend's `voice-persona` skill output lands in `Card.CardContent` as:
/// - `promptText` — Dashy's wondering-aloud question (spoken on card appear).
/// - `expectedResponses` — 1-5 accepted spoken answers. Speech-recognition
///   transcript is matched case-insensitively + whitespace-normalized; a
///   bidirectional `contains` check tolerates the fuzzy near-misses real kids
///   produce ("a kitten" vs "kitten" both match).
/// - `celebration` — Dashy's shared-win line (spoken on match, e.g. "Yes! I
///   knew you'd remember — that word was stuck behind my teeth.").
/// - `retryHint` — Dashy's soft-reset line (spoken on miss, e.g. "Hmm, that's
///   not the one I meant — let me think…"). **Never** a hard correction like
///   "wrong" or "no" — enforced by Zod at the skill validator boundary.
/// - `phonetics` — optional kebab-syllable hint ("pho-to-syn-the-sis"). Unused
///   today; reserved for a future `AVSpeechUtterance.pronunciations` hook to
///   clean up multi-syllable TTS articulation.
///
/// ## Interaction states
///
/// `idle` → tap mic → `listening` → speak → tap mic → `matching` →
/// (`celebrating` | `reprompting`) → `idle` (retry) OR tap Next (advance).
///
/// Match/miss loops back to `idle` with the same prompt on retryHint so the
/// kid gets another try; Next advances the flipbook.
public struct VoiceCardView: View {
    /// The card to display.
    let card: Card

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @EnvironmentObject var voiceManager: VoiceManager

    @State private var phase: Phase = .idle
    @State private var lastTranscript: String = ""
    @State private var matchedCelebration: String = ""
    @State private var missedRetry: String = ""
    @State private var speakTask: Task<Void, Never>?
    @State private var listenTask: Task<Void, Never>?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(card: Card) {
        self.card = card
    }

    /// Where the card is in the ask → listen → react → retry loop.
    private enum Phase: Equatable {
        case idle            // waiting for kid to tap the mic
        case listening       // audio engine hot, capturing transcript
        case matching        // transcript vs expectedResponses
        case celebrating     // match — TTS-playing celebration line
        case reprompting     // miss — TTS-playing retryHint, then back to idle
    }

    public var body: some View {
        ScrollView {
            ChalkboardLessonCardSurface(cardKind: .voice, title: surfaceTitle) {
                VStack(spacing: Spacing.lg) {
                    promptBubble
                    centerStage
                    footer
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
        .onAppear { introOnAppear() }
        .onDisappear { cleanup() }
    }

    private var surfaceTitle: String {
        if let title = card.content.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title
        }
        return "Voice"
    }

    // MARK: - Subviews

    /// Teacher-prompt speech bubble. Hosts the prompt text on the
    /// `lesson_voice_prompt_45` painted bubble asset when present;
    /// falls back to a SwiftUI paper bubble with ink stroke when not.
    @ViewBuilder private var promptBubble: some View {
        if let prompt = card.content.promptText, !prompt.isEmpty {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "person.wave.2.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(NovaPalette.classroomSky)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(NovaPalette.classroomSky.opacity(0.20))
                    )
                    .overlay(
                        Circle().strokeBorder(NovaPalette.classroomInk.opacity(0.45), lineWidth: 2)
                    )
                    .accessibilityHidden(true)

                Text(prompt)
                    .font(NovaPalette.largeBodyFont())
                    .foregroundStyle(NovaPalette.classroomInk)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.85)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(promptBubbleBackground)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    /// Background for the prompt bubble. Uses the painted speech-bubble
    /// asset (`lesson_voice_prompt_45`) when it ships in the bundle so
    /// the prompt reads as a teacher-spoken line; falls back to a paper
    /// rounded-rect with ink stroke when the asset is absent.
    @ViewBuilder
    private var promptBubbleBackground: some View {
        if UIImage(named: "lesson_voice_prompt_45") != nil {
            Image("lesson_voice_prompt_45")
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(NovaPalette.classroomPaper)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(NovaPalette.classroomInk.opacity(0.45), lineWidth: 2)
                )
        }
    }

    @ViewBuilder private var centerStage: some View {
        switch phase {
        case .idle, .listening:
            micStage
        case .matching:
            statusBubble(text: "Thinking…", tone: .neutral)
        case .celebrating:
            statusBubble(text: matchedCelebration, tone: .celebration)
        case .reprompting:
            statusBubble(text: missedRetry, tone: .retry)
        }
    }

    @ViewBuilder private var micStage: some View {
        VStack(spacing: Spacing.md) {
            if phase == .listening, !reduceMotion {
                listeningPulse
            }

            Button {
                toggleMic()
            } label: {
                Image(systemName: phase == .listening ? "mic.fill" : "mic")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 120, height: 120)
                    .background(
                        Circle()
                            .fill(phase == .listening ? NovaPalette.classroomSchoolRed : NovaPalette.classroomInk)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(NovaPalette.classroomInk, lineWidth: 3)
                    )
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityLabel(phase == .listening ? "Stop listening" : "Start listening")
            .accessibilityHint(phase == .listening
                               ? "Double-tap to finish your answer."
                               : "Double-tap to answer Dashy's question.")

            Text(micStatusText)
                .font(NovaPalette.bodyFont())
                .foregroundStyle(NovaPalette.classroomInk.opacity(0.75))
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
    }

    /// A calm pulsing ring around the mic while we're listening.
    /// `TimelineView(.animation)` is the source-level reduce-motion gate —
    /// the `if ... !reduceMotion` guard above prevents this view from even
    /// instantiating under reduce-motion, so the timeline schedule is dropped
    /// entirely rather than rendering a frozen ring.
    private var listeningPulse: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = sin(t * .pi * 1.2) * 0.5 + 0.5 // 0…1
            Circle()
                .strokeBorder(NovaPalette.classroomSchoolRed, lineWidth: 3)
                .frame(width: 140 + CGFloat(phase * 16),
                       height: 140 + CGFloat(phase * 16))
                .opacity(0.3 + phase * 0.3)
        }
        .frame(width: 160, height: 160)
        .accessibilityHidden(true)
    }

    private enum BubbleTone { case neutral, celebration, retry }

    private func statusBubble(text: String, tone: BubbleTone) -> some View {
        VStack(spacing: Spacing.sm) {
            Text(text)
                .font(NovaPalette.largeBodyFont())
                .foregroundStyle(NovaPalette.classroomInk)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .padding(Spacing.md)
                .frame(maxWidth: 520)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(backgroundFill(for: tone))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(NovaPalette.classroomInk, lineWidth: 2)
                )
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private func backgroundFill(for tone: BubbleTone) -> Color {
        switch tone {
        case .neutral:     return NovaPalette.classroomPaper
        case .celebration: return NovaPalette.classroomSun.opacity(0.40)
        case .retry:       return NovaPalette.classroomSchoolRed.opacity(0.18)
        }
    }

    @ViewBuilder private var footer: some View {
        switch phase {
        case .idle:
            if !lastTranscript.isEmpty {
                // Kid has attempted at least once and missed — offer a Next bail-out
                // so they're not trapped in an infinite loop.
                Button("Skip for now") { dismiss() }
                    .novaSecondary()
                    .frame(maxWidth: 320)
            }
        case .celebrating:
            Button("Next →") { dismiss() }
                .novaPrimary()
                .frame(maxWidth: 320)
        case .listening, .matching, .reprompting:
            // Nothing — the kid is in the middle of a turn.
            EmptyView()
        }
    }

    private var micStatusText: String {
        switch phase {
        case .idle:     return "Tap to talk"
        case .listening: return "I'm listening…"
        case .matching:  return "Thinking…"
        default:         return ""
        }
    }

    // MARK: - Flow

    /// Speak Dashy's prompt on appear so the kid hears the question even if
    /// they can't read the on-screen text yet. Uses `voiceScript` when
    /// available (which the backend assembles as `promptText + celebration`
    /// per S12-06) but trimmed to just the prompt here — celebration is held
    /// back for the reward moment.
    private func introOnAppear() {
        guard let prompt = card.content.promptText, !prompt.isEmpty else { return }
        speakTask = Task {
            // S13-09: defaults to OpenAI TTS via backend proxy.
            try? await voiceManager.speak(text: prompt)
        }
    }

    private func toggleMic() {
        switch phase {
        case .idle:
            startListening()
        case .listening:
            stopListeningAndMatch()
        default:
            break
        }
    }

    private func startListening() {
        phase = .listening
        NovaHaptics.tap()
        listenTask = Task { @MainActor in
            do {
                let stream = try await speechRecognizer.startListening()
                // Consume to keep recognition hot — the transcript updates
                // on the recognizer's `@Published var transcript` so we
                // don't actually need the yielded strings here.
                for await _ in stream { }
            } catch {
                // Most commonly: mic / speech authorization denied.
                phase = .idle
                NovaHaptics.wrong()
            }
        }
    }

    private func stopListeningAndMatch() {
        speechRecognizer.stopListening()
        listenTask?.cancel()
        listenTask = nil

        let transcript = speechRecognizer.transcript
        lastTranscript = transcript
        phase = .matching

        if matches(transcript: transcript, against: card.content.expectedResponses ?? []) {
            NovaHaptics.success()
            let line = card.content.celebration?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "Yes! We got it."
            matchedCelebration = line
            phase = .celebrating
            speakTask = Task {
                // S13-09: defaults to OpenAI TTS via backend proxy.
                try? await voiceManager.speak(text: line)
            }
        } else {
            NovaHaptics.wrong()
            let line = card.content.retryHint?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "Hmm, let me think about that again."
            missedRetry = line
            phase = .reprompting
            speakTask = Task {
                // S13-09: defaults to OpenAI TTS via backend proxy.
                try? await voiceManager.speak(text: line)
                // After the retry hint plays, return to idle so the kid can
                // try again with the same prompt still visible.
                await MainActor.run { phase = .idle }
            }
        }
    }

    /// Fuzzy whitelist match. Speech recognition is imperfect and kids say
    /// things slightly differently than the LLM's ideal whitelist entries
    /// ("a kitten" vs "kitten", "mammals" vs "a mammal"). Normalize both
    /// sides (lowercase + whitespace collapse + strip trailing punctuation)
    /// and then accept a bidirectional `contains` — the whitelist entry
    /// appears in the transcript OR the transcript appears in a whitelist
    /// entry. Empty transcript never matches.
    private func matches(transcript: String, against expected: [String]) -> Bool {
        let normalizedTranscript = normalize(transcript)
        guard !normalizedTranscript.isEmpty else { return false }
        for entry in expected {
            let normalizedEntry = normalize(entry)
            guard !normalizedEntry.isEmpty else { continue }
            if normalizedTranscript.contains(normalizedEntry) { return true }
            if normalizedEntry.contains(normalizedTranscript) { return true }
        }
        return false
    }

    private func normalize(_ s: String) -> String {
        let stripped = s
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        // Collapse runs of whitespace into single spaces so "a  kitten"
        // and "a kitten" compare equal.
        let collapsed = stripped
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        // Strip common trailing punctuation the transcript adds.
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: ".,!?"))
    }

    private func cleanup() {
        speakTask?.cancel()
        listenTask?.cancel()
        speakTask = nil
        listenTask = nil
        speechRecognizer.stopListening()
    }
}

// MARK: - Preview

#Preview {
    let card = Card(
        id: UUID(),
        lessonId: UUID(),
        type: .voice,
        sortOrder: 0,
        content: Card.CardContent(
            title: "Mammal word",
            promptText: "I learned a word today for an animal that gives milk to its babies — but I can't remember it. Do you?",
            expectedResponses: ["mammal", "a mammal", "mammals"],
            celebration: "Yes! I was hoping you'd remember — that word was stuck behind my teeth.",
            retryHint: "Hmm, that's not the one I meant — the animal that feeds milk to its babies.",
            phonetics: nil
        )
    )

    return VoiceCardView(card: card)
        .environmentObject(VoiceManager(
            speechSynthesizer: SpeechSynthesizer(),
            remoteTTSClient: nil
        ))
}
