import SwiftUI

/// Card displaying a single quick stat.
public struct QuickStatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    public init(title: String, value: String, icon: String, color: Color = CompanionPalette.novaBlue) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(CompanionPalette.headingFont())
                    .fontWeight(.bold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(CompanionPalette.companionCard)
        .border(CompanionPalette.companionBorder, width: 1)
        .cornerRadius(8)
    }
}

#Preview {
    VStack(spacing: 12) {
        QuickStatsCard(title: "Lessons Published", value: "3", icon: "book.fill", color: CompanionPalette.novaBlue)
        QuickStatsCard(title: "Learning Time", value: "247 min", icon: "clock.fill", color: CompanionPalette.novaOrange)
        QuickStatsCard(title: "Badges Earned", value: "8", icon: "star.fill", color: CompanionPalette.novaYellow)
        QuickStatsCard(title: "Active Streak", value: "5 days", icon: "flame.fill", color: CompanionPalette.novaPink)
    }
    .padding(16)
    .background(CompanionPalette.companionBackground)
}
