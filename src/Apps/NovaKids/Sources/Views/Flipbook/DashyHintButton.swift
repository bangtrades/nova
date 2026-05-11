import SwiftUI
import NovaCore

/// Floating hint button on flipbook cards with Dashy character.
///
/// A circular button in the top-right corner with a 64pt tap target.
/// Tapping shows a hint sheet with Dashy's advice.
public struct DashyHintButton: View {
    /// Whether to show the hint sheet.
    @Binding var showHintSheet: Bool

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
            .frame(width: 64, height: 64)
            .contentShape(Circle())
        }
        .frame(minWidth: 64, minHeight: 64)
        .accessibilityLabel("Hint from Dashy")
        .accessibilityHint("Get a helpful tip about this card")
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
