import SwiftUI
import NovaCore

/// Floating hint button on flipbook cards with Sparky character.
///
/// A circular button (50pt) in the top-right corner with a gentle bounce animation.
/// Tapping shows a hint sheet with Sparky's advice.
public struct SparkyHintButton: View {
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
                // Background circle with purple
                Circle()
                    .fill(NovaPalette.novaPurple)
                    .frame(width: 50, height: 50)

                // Sparky emoji/robot icon
                VStack(spacing: 2) {
                    Image(systemName: "bubble.left.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityLabel("Hint from Sparky")
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
                SparkyHintButton(showHintSheet: .constant(false))
                    .padding(20)
            }
            Spacer()
        }
    }
}
