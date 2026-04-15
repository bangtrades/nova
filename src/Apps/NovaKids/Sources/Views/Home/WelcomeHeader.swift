import SwiftUI

/// Welcome header displayed at the top of the Home screen.
///
/// Shows a greeting with the child's name and a waving emoji animation.
public struct WelcomeHeader: View {
    /// Child's name to display in greeting.
    let childName: String

    @State private var waveRotation: Double = 0

    public init(childName: String) {
        self.childName = childName
    }

    public var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hey \(childName)!")
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(.primary)

                Text("Ready to explore?")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Waving emoji
            Text("👋")
                .font(.largeTitle)
                .rotationEffect(.degrees(waveRotation), anchor: .topTrailing)
                .onAppear {
                    animateWave()
                }
        }
        .padding(24)
        .background(NovaPalette.novaCardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome, \(childName)")
        .accessibilityValue("Ready to explore?")
    }

    private func animateWave() {
        var rotation = waveRotation
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.1)) {
                rotation = rotation == 0 ? 15 : 0
                waveRotation = rotation
            }
        }
    }
}

#Preview {
    WelcomeHeader(childName: "Explorer")
        .padding(20)
}
