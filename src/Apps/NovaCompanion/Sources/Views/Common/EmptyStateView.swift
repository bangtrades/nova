import SwiftUI

/// Generic empty state view for sections with no content.
public struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    public init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.largeTitle.weight(.light))
                .foregroundStyle(.gray)

            VStack(spacing: 8) {
                Text(title)
                    .font(CompanionPalette.headingFont())
                    .fontWeight(.semibold)

                Text(message)
                    .font(CompanionPalette.secondaryBodyFont())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CompanionPalette.novaBlue)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding(32)
    }
}

#Preview {
    EmptyStateView(
        icon: "book",
        title: "No Lessons Yet",
        message: "Create your first lesson to get started",
        actionTitle: "Create Lesson",
        action: {}
    )
    .background(CompanionPalette.companionBackground)
}
