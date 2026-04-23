import SwiftUI
import NovaCore
import NovaVoice

/// Modal sheet showing Dashy's hint with speech bubble design.
///
/// Features:
/// - Speech bubble design with Dashy avatar
/// - Friendly hint text in large font
/// - Speaker button for text-to-speech
/// - "Got it!" dismiss button
/// - Swipe down to dismiss
public struct DashyHintSheet: View {
    /// The hint text to display.
    let hintText: String

    /// View model for accessing text-to-speech.
    @EnvironmentObject var speechSynthesizer: SpeechSynthesizer

    /// For dismissing the sheet.
    @Environment(\.dismiss) var dismiss

    /// Whether the hint is currently being spoken.
    @State private var isSpeaking = false

    public init(hintText: String) {
        self.hintText = hintText
    }

    public var body: some View {
        VStack(spacing: 20) {
            // Header with dismiss gesture hint
            HStack {
                Text("Dashy's Hint")
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(.primary)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()

            // Speech bubble with Dashy avatar — S11-10 reskin:
            //   - Avatar: sun fill + ink 2pt stroke, bubble glyph in ink.
            //     Matches DashyCharacterView's silhouette treatment so the
            //     hint sheet reads as "same character, closer view".
            //   - Body: DashySpeechBubble (no tail here — the avatar sits
            //     above, not beside, so a tail would be misleading). This
            //     replaces the ad-hoc rounded-rect + opacity(0.1) ink tint
            //     that gave a muddy appearance in dark mode.
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(NovaPalette.sun)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .strokeBorder(NovaPalette.ink, lineWidth: 2)
                        )

                    Image(systemName: "bubble.left.fill")
                        .font(NovaPalette.titleFont())
                        .foregroundStyle(NovaPalette.ink)
                        .accessibilityHidden(true)
                }
                .padding(.bottom, 8)

                DashySpeechBubble(tailSide: .none, horizontalPadding: 20, verticalPadding: 16) {
                    Text(hintText)
                        .font(NovaPalette.largeBodyFont())
                        .foregroundStyle(NovaPalette.ink)
                        .lineLimit(nil)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                // Speaker button for TTS
                Button(action: {
                    isSpeaking = true
                    Task {
                        await speechSynthesizer.speak(hintText)
                        isSpeaking = false
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isSpeaking ? "speaker.wave.2.fill" : "speaker.fill")
                            .font(.headline)
                            .accessibilityHidden(true)
                        Text(isSpeaking ? "Reading..." : "Read Aloud")
                            .font(NovaPalette.bodyFont())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(NovaPalette.ink.opacity(0.1))
                    .foregroundStyle(NovaPalette.novaBlue)
                    .cornerRadius(12)
                }
                .disabled(isSpeaking)

                // Got it button
                Button(action: { dismiss() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.headline)
                            .accessibilityHidden(true)
                        Text("Got It!")
                            .font(NovaPalette.bodyFont())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(NovaPalette.novaGreen)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        // S12-01: cap the hint content at 600pt so on an iPad .large
        // detent the speech bubble paragraph doesn't stretch into a
        // 14-word line. Outer maxWidth: .infinity keeps the sheet's
        // background + cornerRadius filling the full presented width.
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .background(NovaPalette.novaBackground)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dashy's hint")
        .accessibilityValue(hintText)
    }
}

// MARK: - RoundedCorner Modifier

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    DashyHintSheet(
        hintText: "Try clicking on the different shapes to see what happens! Each color represents a different concept in AI."
    )
    .environmentObject(SpeechSynthesizer())
}
