import SwiftUI
import NovaCore

/// Kid-friendly onboarding flow shown once on first launch.
///
/// Walks through 4 pages: Meet Dashy, Choose Avatar, Enter Name, and First Mission.
/// Uses TabView with PageTabViewStyle for swiping between pages.
/// Tracks completion via @AppStorage("hasCompletedOnboarding").
public struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false

    @State private var currentPage: Int = 0
    @State private var selectedAvatar: AvatarOption = .robot
    @State private var childName: String = ""
    @State private var showConfetti: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            NovaPalette.novaBackground
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                // Page 1: Meet Dashy
                meetDashyPage()
                    .tag(0)

                // Page 2: Choose Avatar
                chooseAvatarPage()
                    .tag(1)

                // Page 3: Enter Name
                enterNamePage()
                    .tag(2)

                // Page 4: First Mission
                firstMissionPage()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Confetti on final page
            if showConfetti {
                ConfettiView(isActive: $showConfetti)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: - Page Views

    private func meetDashyPage() -> some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated Dashy character
            VStack(spacing: 0) {
                // Dashy head (purple circle with simple features)
                ZStack {
                    Circle()
                        .fill(NovaPalette.novaPurple)
                        .frame(width: 120, height: 120)

                    HStack(spacing: 24) {
                        // Left eye
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .scaleEffect(1.0 + (sin(Date().timeIntervalSince1970 * 2) * 0.1))

                        // Right eye
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .scaleEffect(1.0 + (sin(Date().timeIntervalSince1970 * 2 + 0.2) * 0.1))
                    }
                    .offset(y: -15)

                    // Smile
                    VStack {
                        Path { path in
                            path.move(to: CGPoint(x: 50, y: 50))
                            path.addCurve(
                                to: CGPoint(x: 70, y: 50),
                                control1: CGPoint(x: 55, y: 65),
                                control2: CGPoint(x: 65, y: 65)
                            )
                        }
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 120, height: 120)
                    }
                }
                .offset(y: sin(Date().timeIntervalSince1970) * 4)

                // Waving hand (circle with motion)
                ZStack {
                    Circle()
                        .fill(NovaPalette.novaPurple)
                        .frame(width: 40, height: 40)
                        .offset(x: 45, y: -25)

                    Image(systemName: "hand.raised.fill")
                        .font(NovaPalette.titleFont())
                        .foregroundStyle(NovaPalette.novaYellow)
                        .offset(x: 45, y: -25)
                        .rotation3DEffect(
                            .degrees(sin(Date().timeIntervalSince1970 * 1.5) * 25),
                            axis: (x: 0, y: 1, z: 0)
                        )
                }
            }
            .frame(height: 180)

            Spacer()

            // Text
            VStack(spacing: 12) {
                Text("Meet Dashy!")
                    .font(NovaPalette.titleFont())
                    .foregroundStyle(.primary)

                Text("Hi! I'm Dashy, your AI buddy!")
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            Spacer()

            // Next button
            Button(action: { withAnimation { currentPage = 1 } }) {
                Text("Next")
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(NovaPalette.novaOrange)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
            .accessibilityLabel("Next button")
        }
    }

    private func chooseAvatarPage() -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Choose Your Look!")
                    .font(NovaPalette.titleFont())
                    .foregroundStyle(.primary)

                Text("Pick your favorite character!")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            .padding(.horizontal, 20)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // Grid of avatars (2 columns)
                    ForEach(Array(AvatarOption.allCases.enumerated()), id: \.offset) { index, avatar in
                        if index % 2 == 0 {
                            HStack(spacing: 16) {
                                avatarButton(avatar)

                                if index + 1 < AvatarOption.allCases.count {
                                    avatarButton(AvatarOption.allCases[index + 1])
                                } else {
                                    Spacer()
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 12)
            }

            HStack(spacing: 12) {
                Button(action: { withAnimation { currentPage = 0 } }) {
                    Text("Back")
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(NovaPalette.novaCardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(NovaPalette.novaBlue, lineWidth: 2)
                        )
                }

                Button(action: { withAnimation { currentPage = 2 } }) {
                    Text("Next")
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(NovaPalette.novaOrange)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private func avatarButton(_ avatar: AvatarOption) -> some View {
        Button(action: {
            selectedAvatar = avatar
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }) {
            VStack(spacing: 12) {
                Image(systemName: avatar.systemImageName)
                    .font(.largeTitle)
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(avatar.backgroundColor)
                    .cornerRadius(12)
                    .scaleEffect(selectedAvatar == avatar ? 1.1 : 1.0)

                Text(avatar.displayName)
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .opacity(selectedAvatar == avatar ? 1.0 : 0.7)
        }
        .accessibilityLabel("Avatar: \(avatar.displayName)")
    }

    private func enterNamePage() -> some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("What's Your Name?")
                    .font(NovaPalette.titleFont())
                    .foregroundStyle(.primary)

                Text("Let Dashy know how to say hello!")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)
            .padding(.horizontal, 20)

            Spacer()

            // Large name input
            TextField("Type your name here...", text: $childName)
                .font(NovaPalette.titleFont())
                .multilineTextAlignment(.center)
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                .background(NovaPalette.novaCardBackground)
                .cornerRadius(12)
                .frame(minHeight: 60)
                .padding(.horizontal, 20)
                .accessibilityLabel("Name input field")

            Spacer()

            HStack(spacing: 12) {
                Button(action: { withAnimation { currentPage = 1 } }) {
                    Text("Back")
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(NovaPalette.novaCardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(NovaPalette.novaBlue, lineWidth: 2)
                        )
                }

                Button(action: { withAnimation { currentPage = 3 } }) {
                    Text("Next")
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(NovaPalette.novaOrange)
                        .cornerRadius(12)
                }
                .disabled(childName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private func firstMissionPage() -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Your First Mission!")
                    .font(NovaPalette.titleFont())
                    .foregroundStyle(.primary)
            }
            .padding(.top, 40)

            Spacer()

            // Mini-lesson card
            VStack(spacing: 16) {
                Image(systemName: "lightbulb.fill")
                    .font(.largeTitle)
                    .foregroundStyle(NovaPalette.novaYellow)

                Text("What is AI?")
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(.primary)

                Text("AI is like a smart helper that learns from examples!")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(24)
            .background(NovaPalette.novaCardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .padding(.horizontal, 20)

            Spacer()

            HStack(spacing: 12) {
                Button(action: { withAnimation { currentPage = 2 } }) {
                    Text("Back")
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(NovaPalette.novaCardBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(NovaPalette.novaBlue, lineWidth: 2)
                        )
                }

                Button(action: {
                    hasCompletedOnboarding = true
                    withAnimation { showConfetti = true }
                }) {
                    Text("Let's Go!")
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    NovaPalette.novaOrange,
                                    NovaPalette.novaPurple
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Avatar Options

enum AvatarOption: CaseIterable {
    case robot
    case rocket
    case star
    case planet
    case dinosaur
    case rainbow
    case unicorn
    case astronaut

    var displayName: String {
        switch self {
        case .robot: return "Robot"
        case .rocket: return "Rocket"
        case .star: return "Star"
        case .planet: return "Planet"
        case .dinosaur: return "Dinosaur"
        case .rainbow: return "Rainbow"
        case .unicorn: return "Unicorn"
        case .astronaut: return "Astronaut"
        }
    }

    var systemImageName: String {
        switch self {
        case .robot: return "hare.fill"
        case .rocket: return "arrowshape.up.fill"
        case .star: return "star.fill"
        case .planet: return "globe.europe.africa.fill"
        case .dinosaur: return "hare.fill"
        case .rainbow: return "cloud.sun.rain.fill"
        case .unicorn: return "sparkles"
        case .astronaut: return "suit.heart.fill"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .robot: return NovaPalette.novaBlue
        case .rocket: return NovaPalette.novaPink
        case .star: return NovaPalette.novaYellow
        case .planet: return NovaPalette.novaGreen
        case .dinosaur: return Color(red: 0.8, green: 0.6, blue: 0.2)
        case .rainbow: return NovaPalette.novaPurple
        case .unicorn: return NovaPalette.novaPink
        case .astronaut: return NovaPalette.novaBlue
        }
    }
}


#Preview {
    OnboardingView()
}
