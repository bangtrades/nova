import SwiftUI

/// Subscription plan management view.
public struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPlan: SubscriptionPlan = .free

    enum SubscriptionPlan: String, CaseIterable {
        case free = "Free"
        case pro = "Pro"
        case byok = "Bring Your Own Keys"
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Current Plan
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Current Plan")
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(currentPlan.rawValue)
                                        .font(CompanionPalette.headingFont())
                                        .fontWeight(.bold)

                                    Text("Active plan")
                                        .font(CompanionPalette.captionFont())
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if currentPlan == .free {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2.weight(.semibold))
                                        .foregroundStyle(CompanionPalette.statusPublished)
                                }
                            }
                            .padding(12)
                            .background(CompanionPalette.companionCard)
                            .border(CompanionPalette.companionBorder, width: 1)
                            .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)

                        // Plans Comparison
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available Plans")
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)
                                .padding(.horizontal, 16)

                            VStack(spacing: 12) {
                                planCard(
                                    name: "Free",
                                    price: "$0",
                                    period: "forever",
                                    features: [
                                        "Up to 2 children",
                                        "Basic lesson creation",
                                        "Limited LLM generation",
                                        "Standard support",
                                    ],
                                    isCurrentPlan: currentPlan == .free,
                                    action: {}
                                )

                                planCard(
                                    name: "Pro",
                                    price: "$6.99",
                                    period: "per month",
                                    features: [
                                        "Unlimited children",
                                        "Advanced lesson editor",
                                        "Unlimited LLM generation",
                                        "Priority support",
                                        "Analytics dashboard",
                                    ],
                                    isCurrentPlan: currentPlan == .pro,
                                    action: {}
                                )

                                planCard(
                                    name: "Bring Your Own Keys",
                                    price: "$2.99",
                                    period: "per month",
                                    features: [
                                        "Use your own API keys",
                                        "Unlimited children",
                                        "Advanced lesson editor",
                                        "Full control over costs",
                                    ],
                                    isCurrentPlan: currentPlan == .byok,
                                    action: {}
                                )
                            }
                            .padding(.horizontal, 16)
                        }

                        // FAQ
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Frequently Asked Questions")
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)
                                .padding(.horizontal, 16)

                            faqItem(
                                question: "Can I change plans?",
                                answer: "Yes, you can upgrade or downgrade your plan at any time. Changes take effect immediately."
                            )

                            faqItem(
                                question: "Do I get a refund?",
                                answer: "We offer a 30-day money-back guarantee if you're not satisfied with your plan."
                            )

                            faqItem(
                                question: "What happens to my data?",
                                answer: "Your lessons and children's progress remain safe and accessible regardless of your plan."
                            )
                        }
                        .padding(.horizontal, 16)

                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func planCard(
        name: String,
        price: String,
        period: String,
        features: [String],
        isCurrentPlan: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)

                    HStack(spacing: 0) {
                        Text(price)
                            .font(CompanionPalette.headingFont())
                            .fontWeight(.bold)

                        Text(" / \(period)")
                            .font(CompanionPalette.captionFont())
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isCurrentPlan {
                    Text("Active")
                        .font(CompanionPalette.captionFont())
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(CompanionPalette.statusPublished.opacity(0.2))
                        .foregroundStyle(CompanionPalette.statusPublished)
                        .cornerRadius(4)
                } else {
                    Button(action: action) {
                        Text("Upgrade")
                            .font(CompanionPalette.captionFont())
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(CompanionPalette.novaBlue)
                            .foregroundStyle(.white)
                            .cornerRadius(4)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CompanionPalette.statusPublished)

                        Text(feature)
                            .font(CompanionPalette.captionFont())
                    }
                }
            }
        }
        .padding(12)
        .background(isCurrentPlan ? CompanionPalette.novaBlue.opacity(0.05) : CompanionPalette.companionCard)
        .border(isCurrentPlan ? CompanionPalette.novaBlue : CompanionPalette.companionBorder, width: 1)
        .cornerRadius(8)
    }

    private func faqItem(question: String, answer: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)

            Text(answer)
                .font(CompanionPalette.captionFont())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(CompanionPalette.companionCard)
        .border(CompanionPalette.companionBorder, width: 1)
        .cornerRadius(8)
    }
}

#Preview {
    SubscriptionView()
}
