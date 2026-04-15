import SwiftUI
import NovaCore
import NovaVoice

/// Modal sheet showing Sparky's hint with speech bubble design.
///
/// Features:
/// - Speech bubble design with Sparky avatar
/// - Friendly hint text in large font
/// - Speaker button for text-to-speech
/// - "Got it!" dismiss button
/// - Swipe down to dismiss
public struct SparkyHintSheet: View {
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
                Text("Sparky's Hint")
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

            // Speech bubble with Sparky avatar
            VStack(spacing: 16) {
                // Sparky avatar
                ZStack {
                    Circle()
                        .fill(NovaPalette.novaPurple)
                        .frame(width: 60, height: 60)

                    Image(systemName: "bubble.left.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
                .padding(.bottom, 8)

                // Speech bubble with hint text
                VStack(alignment: .leading, spacing: 12) {
                    Text(hintText)
                        .font(NovaPalette.largeBodyFont())
                        .foregroundStyle(.primary)
                        .lineLimit(nil)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                )
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
                    .background(Color.gray.opacity(0.1))
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
        .background(NovaPalette.novaBackground)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sparky's hint")
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
    SparkyHintSheet(
        hintText: "Try clicking on the different shapes to see what happens! Each color represents a different concept in AI."
    )
    .environmentObject(SpeechSynthesizer())
}
