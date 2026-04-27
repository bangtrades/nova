import SwiftUI
import NovaCore
import NovaVoice

/// S13-08 — Kid-facing voice persona picker.
///
/// Four character cards arranged in a 2×2 grid (iPad-friendly tap targets,
/// each card ≥ 200×200pt). Tapping a card:
///   1. Plays a sample line through the backend TTS proxy with that voice.
///   2. Highlights the card with a gold ring.
///   3. Persists the choice via `VoicePreferenceStore` so subsequent app
///      launches and lesson plays use it automatically.
///
/// Reachable from:
///   - **Settings** (parental gate): adult-mediated change.
///   - **Onboarding**: first-launch nudge for kids with no preference yet.
///   - **Inline from any narration card**: long-press the speaker icon
///      surfaces this as a sheet (deferred to S13-09 sweep).
///
/// **Reduce-motion path:** sample-card scaling collapses to instant; the
/// gold ring still fades in (visual cue is the *information*, not the
/// motion).
///
/// **Accessibility:** every card has a combined element with label
/// "<Name> voice — <tagline>", value "<Selected/Not selected>", hint
/// "Plays a sample. Tap to make this <Name>'s voice."
public struct VoicePickerView: View {
    /// Optional childId — `nil` uses the per-device fallback inside the
    /// store. The picker treats `nil` as legitimate (e.g. pre-profile
    /// onboarding flow).
    let childId: UUID?

    /// Optional dismiss callback when shown as a sheet. `nil` for inline use.
    let onDone: (() -> Void)?

    @EnvironmentObject private var voiceManager: VoiceManager
    @EnvironmentObject private var voicePreferenceStore: VoicePreferenceStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    /// Currently-being-sampled voice (so we can show the playing pulse on the
    /// right card). Distinct from `selectedVoice` because the kid might be
    /// previewing a voice they haven't chosen yet.
    @State private var samplingVoice: String? = nil

    /// Live source-of-truth for which card shows selected. Reads through
    /// `voicePreferenceStore` so an external change re-renders.
    private var selectedVoice: String {
        voicePreferenceStore.voice(for: childId)
    }

    public init(childId: UUID?, onDone: (() -> Void)? = nil) {
        self.childId = childId
        self.onDone = onDone
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                // 2x2 grid of voice cards. LazyVGrid with adaptive sizing so
                // an iPad in portrait gets 2 columns, landscape gets 4 in a
                // single row.
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)
                    ],
                    spacing: 16
                ) {
                    ForEach(VoicePersona.all, id: \.id) { persona in
                        voiceCard(for: persona)
                    }
                }
                .padding(.horizontal, 24)

                if let onDone {
                    Button(action: {
                        onDone()
                        dismiss()
                    }) {
                        HStack(spacing: 10) {
                            Text("Done")
                                .font(NovaPalette.headingFont())
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(NovaPalette.novaOrange))
                        .shadow(color: NovaPalette.novaOrange.opacity(0.45), radius: 10, y: 4)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .accessibilityLabel("Done — keep my voice choice")
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [NovaPalette.page, NovaPalette.novaBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Pick a voice")
        .navigationBarTitleDisplayMode(.inline)
        // S14-VF-02: kid hears "Pick a friend to read your stories. Tap
        // any of them to hear what they sound like!" on appear. Plays
        // in the kid's *current* voice (from VoicePreferenceStore) —
        // intentional: this introduces the picker as "swap the voice
        // I'm currently using" rather than "pick from scratch."
        .narrate("voicePicker")
    }

    // MARK: - Sub-views

    private var header: some View {
        VStack(spacing: 8) {
            Text("Who tells your story?")
                .font(NovaPalette.displayFont(size: 36, relativeTo: .largeTitle))
                .foregroundStyle(NovaPalette.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("Tap a friend to hear them. Pick the one you like best.")
                .font(NovaPalette.bodyFont())
                .foregroundStyle(NovaPalette.ink.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.bottom, 8)
    }

    private func voiceCard(for persona: VoicePersona) -> some View {
        let isSelected = persona.id == selectedVoice
        let isSampling = persona.id == samplingVoice

        return Button {
            handleTap(persona: persona)
        } label: {
            VStack(spacing: 12) {
                // Avatar — colored circle with monogram + animated ring when sampling.
                ZStack {
                    if isSampling && !reduceMotion {
                        Circle()
                            .stroke(persona.color.opacity(0.45), lineWidth: 4)
                            .scaleEffect(1.25)
                            .opacity(0)
                            .animation(
                                .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                                value: isSampling
                            )
                            .frame(width: 96, height: 96)
                    }

                    Circle()
                        .fill(persona.color)
                        .frame(width: 96, height: 96)
                        .shadow(color: persona.color.opacity(0.4), radius: 8, y: 3)

                    Text(persona.monogram)
                        .font(NovaPalette.displayFont(size: 36, relativeTo: .largeTitle))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)

                    if isSampling {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(persona.color.darkened())
                            .clipShape(Circle())
                            .offset(x: 30, y: 30)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                // Name + tagline
                VStack(spacing: 4) {
                    Text(persona.displayName)
                        .font(NovaPalette.displayFont(size: 24, relativeTo: .title2))
                        .foregroundStyle(NovaPalette.ink)

                    Text(persona.tagline)
                        .font(NovaPalette.captionFont())
                        .foregroundStyle(NovaPalette.ink.opacity(0.65))
                }

                // Selection indicator
                if isSelected {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(NovaPalette.sun)
                            .accessibilityHidden(true)
                        Text("Your voice")
                            .font(NovaPalette.captionFont().weight(.semibold))
                            .foregroundStyle(NovaPalette.ink)
                    }
                    .padding(.top, 4)
                } else {
                    Text(" ") // Reserve same vertical space.
                        .font(NovaPalette.captionFont())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: NovaPalette.ink.opacity(0.08), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        isSelected ? NovaPalette.sun : Color.clear,
                        lineWidth: 4
                    )
            )
            .scaleEffect(isSampling && !reduceMotion ? 1.03 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isSampling)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(persona.displayName) voice — \(persona.tagline)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Plays a sample. Tap to make this your voice.")
    }

    // MARK: - Actions

    private func handleTap(persona: VoicePersona) {
        // Always play the sample first — even if already selected the kid
        // might just want to hear it again.
        samplingVoice = persona.id

        // Persist the selection synchronously. Even if the network sample
        // fails, the kid's choice survives — silence is a better failure
        // mode than "voice picker forgot what I picked."
        voicePreferenceStore.setVoice(persona.id, for: childId)
        voiceManager.setVoice(persona.id)

        Task {
            do {
                try await voiceManager.speak(text: persona.sampleText, voice: persona.id)
            } catch {
                // Non-fatal — silent failure means the kid hears AVSpeech
                // (VoiceManager handles fallback internally). Worst case the
                // sample doesn't play at all on this tap.
                print("[VoicePickerView] Sample play failed: \(error.localizedDescription)")
            }
            // Hold the sampling state for ~2s after speak() returns so the
            // pulse + speaker icon don't vanish the moment audio ends.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                if samplingVoice == persona.id {
                    samplingVoice = nil
                }
            }
        }

        // Light haptic — S11-15 ladder. `.tap` on initial, no .commit until
        // the kid hits Done (or auto-confirms via dismiss).
        NovaHaptics.tap()
    }
}

// MARK: - Persona model
//
// VoicePersona is the kid-facing display data. Mirrors the backend
// /voice/voices payload so the mapping (slug → display) is single-sourced
// at backend level for prod, but iOS carries the canonical fallback so
// the picker still works offline / before first /voice/voices fetch.
public struct VoicePersona: Identifiable, Equatable {
    public let id: String           // OpenAI voice slug
    public let displayName: String
    public let tagline: String
    public let monogram: String     // 1-letter avatar
    public let sampleText: String
    public let color: Color

    public static let all: [VoicePersona] = [
        VoicePersona(
            id: "nova",
            displayName: "Nova",
            tagline: "Bright + bouncy",
            monogram: "N",
            sampleText: "Hi! I'm Nova! Let's learn something amazing today!",
            color: NovaPalette.novaOrange
        ),
        VoicePersona(
            id: "fable",
            displayName: "Pip",
            tagline: "Storyteller",
            monogram: "P",
            sampleText: "Hello, little explorer. I'm Pip, and I have ever such a wonderful story to share with you.",
            color: NovaPalette.novaPurple
        ),
        VoicePersona(
            id: "onyx",
            displayName: "Captain Boom",
            tagline: "Brave + bold",
            monogram: "B",
            sampleText: "Greetings, adventurer! Captain Boom here. Ready to go on an amazing journey?",
            color: NovaPalette.novaBlue
        ),
        VoicePersona(
            id: "shimmer",
            displayName: "Sunny",
            tagline: "Warm + gentle",
            monogram: "S",
            sampleText: "Hi sweetheart. I'm Sunny. We're going to have such a nice time learning together.",
            color: NovaPalette.sun
        )
    ]
}

// MARK: - Color helper

private extension Color {
    /// Slightly darken a color for the speaker-icon overlay. Uses UIColor
    /// HSB decomposition when available; falls back to the original color
    /// (no-op) when the bridge isn't available — visual quality is the same
    /// to a kid's eye.
    func darkened(by amount: Double = 0.15) -> Color {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return Color(hue: h, saturation: s, brightness: max(0, b - amount), opacity: a)
        }
        #endif
        return self
    }
}
