import SwiftUI

/// Empty state view shown when no content is available.
///
/// Displays a friendly illustration, message, and subtitle to encourage
/// parents to add content.
public struct EmptyStateView: View {
    /// Title text displayed.
    let title: String

    /// Subtitle text displayed below the title.
    let subtitle: String

    /// Optional icon/emoji to display (defaults to sparkles).
    let icon: String

    public init(
        title: String = "No lessons yet!",
        subtitle: String = "Ask your parent to add some!",
        icon: String = "sparkles"
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }

    public var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Icon with bounce animation
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(NovaPalette.novaBlue)
                .scaleEffect(1.0)
                .animation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                    value: UUID()
                )

            // Title
            Text(title)
                .font(NovaPalette.headingFont())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            // Subtitle
            Text(subtitle)
                .font(NovaPalette.bodyFont())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(NovaPalette.novaBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle)
    }
}

#Preview {
    EmptyStateView()
}
