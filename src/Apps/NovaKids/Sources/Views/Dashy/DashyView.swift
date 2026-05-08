import SwiftUI
import NovaCore
import NovaVoice

/// Full voice chat interface with animated Dashy character.
///
/// S11-13 rebuild lands four coordinated changes on top of the S11-10 reskin:
///   1. **Header** moves from `.headline` / `.caption` system text into the DS
///      type scale (`NovaPalette.headingFont()` + `captionFont()`), and gains
///      a slim **session-time progress bar** below the subtitle — coral fill
///      over a 20-minute window, driven by `TimelineView(.periodic)` so no
///      `Timer` wrapping is needed and `@MainActor` isolation is a non-issue.
///   2. **Chat bubbles** adopt the "Dashy = paper-and-ink / child = coral"
///      rule. Dashy's side stays on `DashySpeechBubble` (S11-10); the child's
///      side flips from `NovaPalette.novaBlue` to `coral` fill with `page`
///      text and a 2pt ink stroke — matches the "coral = the child's pick /
///      the child's turn" semantics established by the quiz answer chip
///      (S11-06) and the filter pill (S11-12).
///   3. **Suggestion + starter pills** both route through
///      `NovaSecondaryButtonStyle` (`.novaSecondary()`) so the Dashy chat
///      surface speaks the same DS button language as every other screen.
///      No more novaOrange arrow accents, no more novaOrange↔novaPurple
///      starter-prompt gradient.
///   4. **Thinking indicator + talk button** gain reduce-motion fallbacks:
///      the "Dashy is thinking" dots cycle when motion is allowed and render
///      as a static "…" when reduce-motion is on; the talk-button fill flips
///      coral (ready) ↔ sun (listening) without a gradient, and the listening
///      pulse ring is motion-gated.
///
/// > Coordinated-rename note: as of S12-07/08 the backend service moved
/// > to `services/dashy/` and the on-wire `role` literal flipped to
/// > `"dashy"` in the same commit range. S11-09's asymmetric carve-out
/// > is now closed.
public struct DashyView: View {
    @StateObject private var viewModel: DashyViewModel
    @EnvironmentObject var apiRouter: APIRouter
    @EnvironmentObject var voiceManager: VoiceManager

    @State private var animationState: DashyAnimationState = .idle
    @State private var inputText: String = ""
    @State private var showCelebration: Bool = false
    @State private var celebrationTask: Task<Void, Never>?

    // Session-time window — the progress bar fills to 100% over this many
    // seconds from the view's first render. 20 minutes is a commonly-cited
    // "one focused chat session" cap for this age group; the bar is a gentle
    // nudge, not an enforced limit.
    private static let sessionWindowSeconds: TimeInterval = 20 * 60

    // First-render timestamp — captured lazily via `.onAppear` so the bar
    // starts at 0% every time the tab is opened. Stored as a state-bound
    // optional so the view can distinguish "never appeared" (bar empty) from
    // "appeared at time T" (bar interpolates from T).
    @State private var sessionStartedAt: Date?

    // Reduce-motion + Dynamic Type hooks used across subviews.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Hard-coded placeholder host the `DashyView()` no-arg init uses
    /// for the `DashyViewModel` it owns before the real `APIRouter` is
    /// injected by the parent. The string is a constant; the optional
    /// is unwrapped here at compile-evaluation time so a future typo
    /// surfaces as a non-nil sentinel URL instead of a runtime crash
    /// inside a child-facing view.
    private static let placeholderBaseURL: URL = {
        // `URL(string:)` returns nil only when the string is malformed
        // per RFC 3986. The literal here is a well-formed https URL —
        // but if it ever becomes malformed, fall back to `about:blank`
        // so the kid sees an empty Dashy state rather than a crash.
        URL(string: "https://api.nova.local")
            ?? URL(string: "about:blank")
            ?? URL(fileURLWithPath: "/")
    }()

    public init() {
        // Placeholder initialization — will be injected by parent
        _viewModel = StateObject(wrappedValue: DashyViewModel(
            apiRouter: APIRouter(apiClient: APIClient(
                baseURL: Self.placeholderBaseURL,
                tokenProvider: EmptyTokenProvider()
            )),
            voiceManager: VoiceManager(speechSynthesizer: SpeechSynthesizer())
        ))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                NovaPalette.novaBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    // Conversation area
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: Spacing.md) {
                            // Chat history
                            ForEach(viewModel.conversationHistory) { message in
                                chatBubble(message)
                            }

                            // Character and responses
                            VStack(spacing: Spacing.lg) {
                                // Dashy character
                                DashyCharacterView(state: $animationState)
                                    .frame(height: 200)
                                    .padding(.horizontal, Spacing.xl + Spacing.sm)

                                // Processing indicator — animated dots when
                                // motion allowed, static "…" when reduce-motion
                                // is on. Owns its own time base via TimelineView
                                // so nothing in the parent has to wrangle a Timer.
                                if viewModel.state == .responding || viewModel.state == .processing {
                                    thinkingIndicator
                                }

                                // Suggestions ("Try asking:")
                                if !viewModel.suggestions.isEmpty && viewModel.state == .ready {
                                    suggestionList
                                }

                                // Starter prompts (when no conversation has started)
                                if viewModel.conversationHistory.isEmpty && viewModel.state == .ready {
                                    starterPromptList
                                }

                                // Error message
                                if case let .error(message) = viewModel.state {
                                    errorCard(message: message)
                                }
                            }
                        }
                        .padding(.vertical, Spacing.lg)
                    }

                    // Input row
                    inputBar
                }
            }
            .novaNavigationStyle()
            .onAppear {
                // Capture the session start once; subsequent .onAppear firings
                // (tab re-selection without unmount) do not reset the timer.
                if sessionStartedAt == nil {
                    sessionStartedAt = Date()
                }
            }
            .onChange(of: viewModel.state) { _, newState in
                updateAnimationState(newState)
            }
            .onChange(of: viewModel.currentEmotion) { _, emotion in
                updateAnimationFromEmotion(emotion)
            }
            .onDisappear {
                celebrationTask?.cancel()
            }
        }
    }

    // MARK: - Header

    /// Header — title + subtitle in DS type + a session-time progress bar.
    ///
    /// The bar renders inside a `TimelineView(.periodic)` so the fill fraction
    /// updates once per second without a `Timer` or `@MainActor` hop. Under
    /// reduce-motion, the `TimelineView` schedule is coarsened to every 5s so
    /// the bar doesn't animate smoothly but still eventually reflects the
    /// current session duration.
    private var header: some View {
        VStack(spacing: Spacing.sm) {
            Text("Talk to Dashy")
                .font(NovaPalette.smallHeadingFont())
                .foregroundStyle(NovaPalette.ink)

            Text("Ask me anything about AI and learning!")
                .font(NovaPalette.captionFont())
                .foregroundStyle(NovaPalette.ink.opacity(0.7))

            sessionProgressBar
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xs)
        }
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity)
    }

    /// Session-time progress bar — coral fill over a page-tinted ink-outlined
    /// 4pt rail. The fraction comes from `elapsedFraction(at:)` inside a
    /// `TimelineView(.periodic)` so there's no stored ticking state.
    private var sessionProgressBar: some View {
        TimelineView(.periodic(from: .now, by: reduceMotion ? 5 : 1)) { context in
            GeometryReader { geo in
                let fraction = elapsedFraction(at: context.date)
                ZStack(alignment: .leading) {
                    // Rail — ink-outlined page fill so the bar reads as a
                    // drawn-on-paper tracker, not a system progress bar.
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(NovaPalette.page)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .stroke(NovaPalette.ink.opacity(0.4), lineWidth: 1)
                        )
                    // Coral fill — width comes from fraction × rail width.
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(NovaPalette.coral)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * fraction)))
                }
            }
            .frame(height: 4)
            .accessibilityElement()
            .accessibilityLabel("Session time")
            .accessibilityValue(sessionAccessibilityValue(at: context.date))
        }
    }

    /// Fraction of the session window elapsed at the given sample time.
    /// Clamped to [0, 1] so the bar can't overshoot past 20 minutes.
    private func elapsedFraction(at now: Date) -> CGFloat {
        guard let start = sessionStartedAt else { return 0 }
        let elapsed = now.timeIntervalSince(start)
        let fraction = elapsed / Self.sessionWindowSeconds
        return CGFloat(min(max(fraction, 0), 1))
    }

    private func sessionAccessibilityValue(at now: Date) -> String {
        guard let start = sessionStartedAt else { return "Not started" }
        let elapsed = Int(now.timeIntervalSince(start))
        let minutes = elapsed / 60
        return "\(minutes) of 20 minutes"
    }

    // MARK: - Conversation bubbles

    private func chatBubble(_ message: ChatMessage) -> some View {
        HStack(spacing: Spacing.sm) {
            // Wire-protocol role literal: "user" vs "dashy" (server-authored).
            if message.role == "dashy" {
                dashyBubble(message: message)
            } else {
                childBubble(message: message)
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    /// Dashy message — sun avatar + ink-outlined `DashySpeechBubble` with a
    /// leading tail. Unchanged from the S11-10 reskin; this view just hosts it.
    private func dashyBubble(message: ChatMessage) -> some View {
        HStack(spacing: Spacing.sm) {
            ZStack {
                Circle()
                    .fill(NovaPalette.sun)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .strokeBorder(NovaPalette.ink, lineWidth: 2)
                    )

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.caption)
                    .foregroundStyle(NovaPalette.ink)
                    .accessibilityHidden(true)
            }

            DashySpeechBubble(tailSide: .leading) {
                Text(message.content)
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(NovaPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }

    /// Child (user) message — coral-filled ink-outlined pill, page text. No
    /// speech-bubble tail: the tail idiom is reserved for Dashy's voice (the
    /// comic-world character) per the S11-10 design note. Coral signals "this
    /// is the child's pick / the child's turn" — consistent with the quiz
    /// answer chip (S11-06) and the path filter pill (S11-12).
    private func childBubble(message: ChatMessage) -> some View {
        HStack(spacing: 0) {
            Spacer()

            Text(message.content)
                .font(NovaPalette.bodyFont())
                .foregroundStyle(NovaPalette.page)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm + Spacing.xs)
                .background(
                    NovaPalette.coral,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(NovaPalette.ink, lineWidth: 2)
                )
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Thinking indicator

    /// "Dashy is thinking" — three coral dots that pulse in sequence when
    /// motion is allowed; a static "…" row when reduce-motion is on. Both
    /// variants sit on a `TimelineView(.periodic)` driver so no Timer is
    /// involved and there's no @MainActor hop required.
    private var thinkingIndicator: some View {
        VStack(spacing: Spacing.sm) {
            if reduceMotion {
                HStack(spacing: Spacing.xs) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(NovaPalette.coral)
                            .frame(width: 8, height: 8)
                    }
                }
                .accessibilityHidden(true)
            } else {
                TimelineView(.periodic(from: .now, by: 0.3)) { context in
                    // Rotate through 0/1/2 every 0.3s so one dot at a time
                    // reads as "active". Phase-derived from seconds so the
                    // indicator doesn't drift even if the view unmounts and
                    // re-mounts mid-session.
                    let phase = Int(context.date.timeIntervalSinceReferenceDate / 0.3) % 3
                    HStack(spacing: Spacing.xs) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(NovaPalette.coral)
                                .frame(width: 8, height: 8)
                                .opacity(index == phase ? 1.0 : 0.35)
                        }
                    }
                    .accessibilityHidden(true)
                }
            }

            Text("Dashy is thinking…")
                .font(NovaPalette.captionFont())
                .foregroundStyle(NovaPalette.ink.opacity(0.7))
                .accessibilityLabel("Dashy is thinking")
        }
        .padding(.horizontal, Spacing.xl + Spacing.sm)
    }

    // MARK: - Suggestions + starters

    /// Active conversation suggestions — each pill applies `.novaSecondary()`
    /// so the chat surface shares the same button language as the rest of the
    /// app. Coral text carries forward the "this is a tappable pill" semantics
    /// the secondary style establishes elsewhere.
    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Try asking:")
                .font(NovaPalette.smallHeadingFont())
                .foregroundStyle(NovaPalette.ink.opacity(0.7))
                .padding(.horizontal, Spacing.lg)

            VStack(spacing: Spacing.sm) {
                ForEach(viewModel.suggestions.indices, id: \.self) { index in
                    let suggestion = viewModel.suggestions[index]
                    Button(action: { viewModel.sendMessage(text: suggestion) }) {
                        HStack {
                            Text(suggestion)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            Image(systemName: "arrow.right")
                                .accessibilityHidden(true)
                        }
                    }
                    .novaSecondary()
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.vertical, Spacing.sm)
    }

    /// Starter prompts — fixed four-question set shown on an empty history.
    /// Same `.novaSecondary()` treatment as `suggestionList` so the child
    /// doesn't learn two shapes for "Dashy is offering me a question to ask".
    private var starterPromptList: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("What should I ask?")
                .font(NovaPalette.smallHeadingFont())
                .foregroundStyle(NovaPalette.ink.opacity(0.7))
                .padding(.horizontal, Spacing.lg)

            let starterPrompts = [
                "What is AI?",
                "How do robots learn?",
                "Can you teach me something new?",
                "Tell me a fun fact!"
            ]
            VStack(spacing: Spacing.sm) {
                ForEach(starterPrompts.indices, id: \.self) { index in
                    let prompt = starterPrompts[index]
                    Button(action: { viewModel.sendMessage(text: prompt) }) {
                        Text(prompt)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .novaSecondary()
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Error card

    /// Error card — page-fill + ink-outline (DS card chrome), coral icon for
    /// the "something went wrong" semantic, and a primary-style "Try Again"
    /// button so the recovery affordance reads as the one meaningful action
    /// on the card.
    private func errorCard(message: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title3)
                .foregroundStyle(NovaPalette.coral)
                .accessibilityHidden(true)

            Text(message)
                .font(NovaPalette.bodyFont())
                .foregroundStyle(NovaPalette.ink)
                .multilineTextAlignment(.center)

            Button("Try Again") { viewModel.clearHistory() }
                .novaPrimary()
        }
        .padding(Spacing.lg)
        .background(
            NovaPalette.page,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(NovaPalette.ink, lineWidth: 2)
        )
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Input bar

    /// Text input + send + primary "Talk to Dashy" mic button row.
    private var inputBar: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                TextField("Type your question…", text: $inputText)
                    .font(NovaPalette.bodyFont())
                    .padding(.horizontal, Spacing.md - Spacing.xs)
                    .padding(.vertical, Spacing.sm + Spacing.xs / 2)
                    .background(
                        NovaPalette.page,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(NovaPalette.ink.opacity(0.4), lineWidth: 1)
                    )

                Button(action: {
                    guard !inputText.isEmpty else { return }
                    viewModel.sendMessage(text: inputText)
                    inputText = ""
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.headline)
                        .foregroundStyle(NovaPalette.ink)
                        .frame(width: 48, height: 48)
                        .background(
                            NovaPalette.coral,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(NovaPalette.ink, lineWidth: 2)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, Spacing.lg)

            talkButton
                .padding(.horizontal, Spacing.lg)
        }
        .padding(.vertical, Spacing.md)
    }

    /// Primary push-to-talk button. Coral fill in ready state, sun fill when
    /// actively listening — one-step color change signals state without a
    /// gradient. Listening pulse ring is reduce-motion gated.
    private var talkButton: some View {
        Button(action: toggleListening) {
            ZStack {
                // Pulse ring — visible only while listening and motion is
                // allowed. Wrapped in a TimelineView so SwiftUI actually
                // re-renders the scale/opacity interpolation each tick; a
                // bare computed property wouldn't animate because nothing
                // would invalidate the view after the state flip.
                if viewModel.state == .listening && !reduceMotion {
                    TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { context in
                        let phase = (sin(context.date.timeIntervalSinceReferenceDate * 2 * .pi / 1.2) + 1) / 2
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(NovaPalette.ink.opacity(0.4), lineWidth: 2)
                            .scaleEffect(1.0 + CGFloat(phase) * 0.04)
                            .opacity(0.3 + phase * 0.5)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }

                HStack(spacing: Spacing.sm) {
                    Image(systemName: viewModel.state == .listening ? "mic.fill" : "mic")
                        .font(.title3)

                    Text(viewModel.state == .listening ? "Release to Send" : "Talk to Dashy")
                        .font(NovaPalette.bodyFont().weight(.semibold))
                }
                .foregroundStyle(NovaPalette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(
                    viewModel.state == .listening ? NovaPalette.sun : NovaPalette.coral,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(NovaPalette.ink, lineWidth: 2)
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(viewModel.state == .processing || viewModel.state == .responding)
        .opacity((viewModel.state == .processing || viewModel.state == .responding) ? 0.5 : 1.0)
        .accessibilityLabel(viewModel.state == .listening ? "Release to send" : "Talk to Dashy")
        .accessibilityHint("Tap to speak to Dashy")
    }

    // MARK: - Actions

    private func toggleListening() {
        if viewModel.state == .listening {
            viewModel.stopListening()
            animationState = .idle
        } else if viewModel.state == .ready {
            viewModel.startListening()
            animationState = .listening
        }
    }

    // MARK: - Animation state bridges

    private func updateAnimationState(_ state: DashyState) {
        switch state {
        case .ready:
            animationState = .idle
        case .listening:
            animationState = .listening
        case .processing:
            animationState = .thinking
        case .responding:
            animationState = .talking
        case .error:
            animationState = .idle
        }
    }

    private func updateAnimationFromEmotion(_ emotion: DashyEmotion) {
        switch emotion {
        case .happy, .excited:
            // S11-16: Dashy emotion celebration is per-response ambient motion,
            // not a one-shot completion beat like BadgeUnlockBurst or ConfettiView.
            // Fires every happy/excited response — many times per chat session —
            // so it gates under reduce-motion to avoid repeated scale/pulse
            // animations. Celebration state still flips so VoiceOver + state
            // machine observers see the semantic beat; just without the motion.
            withAnimation(reduceMotion ? nil : .default) { showCelebration = true }
            celebrationTask?.cancel()
            celebrationTask = Task {
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .default) { showCelebration = false }
            }
        default:
            break
        }
    }
}

// MARK: - Empty Token Provider

private class EmptyTokenProvider: TokenProvider {
    var accessToken: String? {
        get async { nil }
    }

    var refreshToken: String? {
        get async { nil }
    }

    func updateTokens(accessToken: String, refreshToken: String) async {}
    func clearTokens() async {}
}

#Preview {
    DashyView()
        .environmentObject(VoiceManager(speechSynthesizer: SpeechSynthesizer()))
}
