import SwiftUI
import NovaCore

/// Floating hint button on flipbook cards with Dashy character.
///
/// A circular button (50pt) in the top-right corner with a gentle bounce animation.
/// Tapping shows a hint sheet with Dashy's advice.
public struct DashyHintButton: View {
    /// Whether to show the hint sheet.
    @Binding var showHintSheet: Bool

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    public init(showHintSheet: Binding<Bool>) {
        self._showHintSheet = showHintSheet
    }

    public var body: some View {
        Button(action: {
            showHintSheet = true
        }) {
            ZStack {
                // S11-10 reskin: `coral` fill + `ink` 2pt stroke puts this
                // gateway button in the same comic-palette family as the
                // character body. Coral reads as "action" in the 3+1
                // system, which fits — tapping this IS the Dashy action
                // on the flipbook card.
                Circle()
                    .fill(NovaPalette.coral)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .strokeBorder(NovaPalette.ink, lineWidth: 2)
                    )

                // Glyph in ink so it reads against the coral fill with the
                // same weight as the body silhouette stroke.
                VStack(spacing: 2) {
                    Image(systemName: "bubble.left.fill")
                        .font(.title3)
                        .foregroundStyle(NovaPalette.ink)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityLabel("Hint from Dashy")
        .accessibilityHint("Get a helpful tip about this card")
        .scaleEffect(1.0)
        .animation(
            reduceMotion ? .none : Animation.spring(response: 0.6, dampingFraction: 0.6)
                .delay(0.0),
            value: UUID()
        )
        .onAppear {
            // Gentle bounce on appearance
            withAnimation(
                reduceMotion ? .none : Animation.spring(response: 0.6, dampingFraction: 0.6)
            ) {
                // Animation trigger
            }
        }
    }
}

#Preview {
    ZStack {
        NovaPalette.novaBackground
            .ignoresSafeArea()

        VStack {
            HStack {
                Spacer()
                DashyHintButton(showHintSheet: .constant(false))
                    .padding(20)
            }
            Spacer()
        }
    }
}
