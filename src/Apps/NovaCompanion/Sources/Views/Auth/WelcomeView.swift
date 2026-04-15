import SwiftUI

/// Onboarding carousel introducing Companion app features.
public struct WelcomeView: View {
    @State private var currentSlide = 0
    @Environment(\.dismiss) var dismiss

    private let slides = [
        WelcomeSlide(
            icon: "book.circle.fill",
            title: "Curate Content",
            description: "Create, edit, and publish AI-powered lessons tailored to your child's learning stage"
        ),
        WelcomeSlide(
            icon: "chart.bar.fill",
            title: "Track Progress",
            description: "Monitor learning sessions, badges earned, and watch your child grow"
        ),
        WelcomeSlide(
            icon: "cpu.fill",
            title: "Connect AI",
            description: "Configure LLM providers to power your lessons with the latest AI models"
        ),
    ]

    public var body: some View {
        ZStack {
            CompanionPalette.companionBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close Button
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                // Carousel
                VStack(spacing: 48) {
                    TabView(selection: $currentSlide) {
                        ForEach(slides.indices, id: \.self) { index in
                            slideView(slides[index])
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(maxHeight: .infinity)

                    // Page Indicators
                    HStack(spacing: 8) {
                        ForEach(slides.indices, id: \.self) { index in
                            Circle()
                                .fill(index == currentSlide ? CompanionPalette.novaBlue : Color.gray.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }

                    // Navigation Buttons
                    HStack(spacing: 12) {
                        if currentSlide > 0 {
                            Button(action: { withAnimation { currentSlide -= 1 } }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(CompanionPalette.novaBlue)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(CompanionPalette.companionBorder))
                            }
                        }

                        if currentSlide < slides.count - 1 {
                            Button(action: { withAnimation { currentSlide += 1 } }) {
                                HStack {
                                    Text("Next")
                                    Image(systemName: "chevron.right")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(CompanionPalette.novaBlue)
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                            }
                        } else {
                            Button(action: { dismiss() }) {
                                Text("Get Started")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(CompanionPalette.novaBlue)
                                    .foregroundStyle(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private func slideView(_ slide: WelcomeSlide) -> some View {
        VStack(spacing: 24) {
            Image(systemName: slide.icon)
                .font(.largeTitle.weight(.light))
                .foregroundStyle(CompanionPalette.novaBlue)
                .padding(.bottom, 16)

            VStack(spacing: 12) {
                Text(slide.title)
                    .font(CompanionPalette.headingFont())
                    .fontWeight(.semibold)

                Text(slide.description)
                    .font(CompanionPalette.secondaryBodyFont())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WelcomeSlide {
    let icon: String
    let title: String
    let description: String
}

#Preview {
    WelcomeView()
}
