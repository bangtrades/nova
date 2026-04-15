import SwiftUI
import NovaCore

/// Subscription tier badge showing current tier status.
public struct TierBadgeView: View {
    let tier: String

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tierIcon)
                .font(.caption.weight(.semibold))

            Text(tier)
                .font(CompanionPalette.captionFont())
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(tierBackgroundColor)
        .foregroundStyle(tierForegroundColor)
        .cornerRadius(6)
    }

    private var tierIcon: String {
        switch tier.lowercased() {
        case "pro":
            return "star.fill"
        case "byok":
            return "key.fill"
        default:
            return "circle.fill"
        }
    }

    private var tierBackgroundColor: Color {
        switch tier.lowercased() {
        case "pro":
            return Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.2)
        case "byok":
            return CompanionPalette.novaPurple.opacity(0.2)
        default:
            return Color.gray.opacity(0.1)
        }
    }

    private var tierForegroundColor: Color {
        switch tier.lowercased() {
        case "pro":
            return Color(red: 1.0, green: 0.84, blue: 0.0)
        case "byok":
            return CompanionPalette.novaPurple
        default:
            return .gray
        }
    }
}

/// Wrapper view that gates content behind tier requirements and shows upgrade prompt.
public struct TierGateView<Content: View>: View {
    let requiredTier: String
    let currentTier: String
    let featureName: String
    @ViewBuilder let content: () -> Content

    public var body: some View {
        if isTierSufficient {
            content()
        } else {
            upgradePromptView
        }
    }

    @ViewBuilder
    private var upgradePromptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.title.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Unlock \(featureName)")
                    .font(CompanionPalette.headingFont())
                    .fontWeight(.bold)

                Text("This feature is available with Nova \(requiredTier)")
                    .font(CompanionPalette.secondaryBodyFont())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {}) {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                    Text("Upgrade to \(requiredTier)")
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(CompanionPalette.novaBlue)
                .foregroundStyle(.white)
                .cornerRadius(8)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CompanionPalette.companionBackground)
    }

    private var isTierSufficient: Bool {
        let tierHierarchy = ["Free": 0, "Pro": 1, "BYOK": 2]
        let currentLevel = tierHierarchy[currentTier] ?? 0
        let requiredLevel = tierHierarchy[requiredTier] ?? 1
        return currentLevel >= requiredLevel
    }
}

/// Usage meter showing subscription quota usage.
public struct UsageMeterView: View {
    let used: Int
    let total: Int
    let label: String

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(CompanionPalette.bodyFont())
                    .fontWeight(.semibold)

                Spacer()

                Text("\(used) of \(total) used")
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(CompanionPalette.companionBorder)

                    let progress = Double(used) / Double(total)
                    let progressColor = usageColor(progress: progress)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 8)
        }
        .padding(12)
        .background(CompanionPalette.companionCard)
        .border(CompanionPalette.companionBorder, width: 1)
        .cornerRadius(8)
    }

    private func usageColor(progress: Double) -> Color {
        if progress > 0.9 {
            return CompanionPalette.novaPink
        } else if progress > 0.7 {
            return CompanionPalette.novaOrange
        } else {
            return CompanionPalette.novaGreen
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TierBadgeView(tier: "Free")
        TierBadgeView(tier: "Pro")
        TierBadgeView(tier: "BYOK")

        Divider()

        UsageMeterView(
            used: 12,
            total: 50,
            label: "AI Generations Used This Month"
        )
        .padding(16)

        Divider()

        TierGateView(
            requiredTier: "Pro",
            currentTier: "Free",
            featureName: "Advanced Analytics"
        ) {
            Text("This is Pro-only content")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CompanionPalette.companionCard)
        }
    }
    .padding(16)
}
