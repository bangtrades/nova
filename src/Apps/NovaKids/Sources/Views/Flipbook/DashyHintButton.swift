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
                // Workbook reskin: classroom-school-red fill +
                // classroom-ink 2pt stroke + soft drop shadow puts
                // the hint button in the same sticker family as the
                // classroom-home tap stickers and the lesson-reader
                // page-turn buttons. Red reads as "action" inside
                // the warm classroom palette without pulling the
                // whole reader back into the S11 comic look.
                Circle()
                    .fill(NovaPalette.classroomSchoolRed)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .strokeBorder(NovaPalette.classroomInk, lineWidth: 2)
                    )
                    .shadow(color: NovaPalette.classroomInk.opacity(0.30), radius: 4, x: 0, y: 2)

                // Speech-bubble glyph in classroom paper so it reads
                // against the red sticker without competing with the
                // ink outline.
                Image(systemName: "bubble.left.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(NovaPalette.classroomPaper)
                    .accessibilityHidden(true)
            }
        }
        .frame(minWidth: 52, minHeight: 52)
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
