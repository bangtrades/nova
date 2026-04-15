import SwiftUI
import NovaCore

/// Parent onboarding wizard shown on first launch.
/// Step 1: Welcome, Step 2: Add Child, Step 3: Connect AI, Step 4: First Lesson
public struct CompanionOnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("hasCompletedCompanionOnboarding") var hasCompletedOnboarding = false

    @State private var currentStep: Int = 0
    @State private var childName: String = ""
    @State private var childAge: Int = 4
    @State private var selectedAvatar: String = "robot"
    @State private var isConnectingOAuth: Bool = false
    @State private var showSkipConfirmation: Bool = false
    @State private var oauthTask: Task<Void, Never>?

    let avatarOptions = ["robot", "rocket", "star", "planet", "dinosaur", "rainbow", "unicorn", "astronaut"]

    public var body: some View {
        ZStack {
            CompanionPalette.companionBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress Indicator at top
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentStep ? CompanionPalette.novaBlue : Color(UIColor.systemGray4))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                TabView(selection: $currentStep) {
                    // Step 1: Welcome
                    welcomeStep()
                        .tag(0)

                    // Step 2: Add Child
                    addChildStep()
                        .tag(1)

                    // Step 3: Connect AI
                    connectAIStep()
                        .tag(2)

                    // Step 4: First Lesson
                    firstLessonStep()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .indexViewStyle(.page(backgroundDisplayMode: .never))

                // Action Buttons
                HStack(spacing: 12) {
                    if currentStep > 0 && currentStep < 3 {
                        Button(action: { withAnimation { currentStep -= 1 } }) {
                            Text("Back")
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundStyle(CompanionPalette.novaBlue)
                        }
                    }

                    if currentStep < 3 {
                        Button(action: { showSkipConfirmation = true }) {
                            Text("Skip")
                                .font(CompanionPalette.captionFont())
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button(action: continueAction) {
                        HStack {
                            Text(buttonTitle)
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)

                            if isConnectingOAuth && currentStep == 2 {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CompanionPalette.novaBlue)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isConnectingOAuth || !isStepValid)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
        .confirmationDialog("Skip Onboarding", isPresented: $showSkipConfirmation) {
            Button("Complete Setup", role: .cancel) {
                finishOnboarding()
            }
            Button("Skip for Now") {
                finishOnboarding()
            }
        } message: {
            Text("You can complete these steps anytime in Settings.")
        }
        .onDisappear {
            oauthTask?.cancel()
        }
    }

    @ViewBuilder
    private func welcomeStep() -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "star.fill")
                    .font(.largeTitle)
                    .foregroundStyle(CompanionPalette.novaBlue)

                Text("Welcome to Nova Companion")
                    .font(CompanionPalette.titleFont())
                    .fontWeight(.bold)

                Text("Empower your child's AI learning journey")
                    .font(CompanionPalette.secondaryBodyFont())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 24)

            VStack(alignment: .leading, spacing: 12) {
                featureBullet(icon: "book.fill", title: "Create Lessons", subtitle: "Design interactive AI-powered lessons from URLs or your ideas")
                featureBullet(icon: "chart.bar.fill", title: "Track Progress", subtitle: "Monitor learning milestones, badges, and activity streaks")
                featureBullet(icon: "cpu.fill", title: "Control AI", subtitle: "Use your own API key or try our Pro subscription")
            }

            Spacer()
        }
        .padding(24)
    }

    @ViewBuilder
    private func addChildStep() -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "person.fill.badge.plus")
                    .font(.largeTitle)
                    .foregroundStyle(CompanionPalette.novaOrange)

                Text("Add Your Child")
                    .font(CompanionPalette.titleFont())
                    .fontWeight(.bold)

                Text("Let's set up a profile")
                    .font(CompanionPalette.secondaryBodyFont())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Child's Name")
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)

                    TextField("e.g., Alex", text: $childName)
                        .font(CompanionPalette.bodyFont())
                        .padding(12)
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Age")
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)

                    Picker("Age", selection: $childAge) {
                        ForEach(4...8, id: \.self) { age in
                            Text("\(age) years old").tag(age)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Avatar")
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60), spacing: 12)], spacing: 12) {
                        ForEach(avatarOptions, id: \.self) { avatar in
                            avatarOption(avatar)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(24)
    }

    @ViewBuilder
    private func connectAIStep() -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "cpu.fill")
                    .font(.largeTitle)
                    .foregroundStyle(CompanionPalette.novaPurple)

                Text("Connect AI Provider")
                    .font(CompanionPalette.titleFont())
                    .fontWeight(.bold)

                Text("Choose how to power lessons")
                    .font(CompanionPalette.secondaryBodyFont())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)

            VStack(spacing: 16) {
                Text("You have two options:")
                    .font(CompanionPalette.bodyFont())
                    .fontWeight(.semibold)

                infoCard(
                    icon: "lock.fill",
                    title: "Bring Your Own Key",
                    subtitle: "Use your OpenAI API key for complete privacy",
                    color: CompanionPalette.novaBlue
                )

                infoCard(
                    icon: "star.fill",
                    title: "Nova Pro",
                    subtitle: "Use our infrastructure with built-in safety filters",
                    color: CompanionPalette.novaYellow
                )

                Text("You can change this anytime in Settings.")
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(24)
    }

    @ViewBuilder
    private func firstLessonStep() -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "link.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(CompanionPalette.novaGreen)

                Text("Your First Lesson")
                    .font(CompanionPalette.titleFont())
                    .fontWeight(.bold)

                Text("Let's create something amazing")
                    .font(CompanionPalette.secondaryBodyFont())
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)

            VStack(spacing: 16) {
                Text("Nova Companion can turn any web page into an interactive lesson.")
                    .font(CompanionPalette.bodyFont())

                infoCard(
                    icon: "lightbulb.fill",
                    title: "Try this:",
                    subtitle: "Paste a link about 'How robots learn' and we'll create a lesson automatically",
                    color: CompanionPalette.novaOrange
                )

                Text("You can also write lessons manually from scratch.")
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(24)
    }

    @ViewBuilder
    private func featureBullet(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(CompanionPalette.novaBlue)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(CompanionPalette.bodyFont())
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func infoCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(color)

                Text(title)
                    .font(CompanionPalette.bodyFont())
                    .fontWeight(.semibold)

                Spacer()
            }

            Text(subtitle)
                .font(CompanionPalette.captionFont())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func avatarOption(_ avatar: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: avatarSystemImage(avatar))
                .font(.title.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(avatarColor(avatar))
                .clipShape(Circle())
        }
        .onTapGesture {
            selectedAvatar = avatar
        }
        .opacity(selectedAvatar == avatar ? 1.0 : 0.6)
        .overlay(
            Circle()
                .stroke(CompanionPalette.novaBlue, lineWidth: selectedAvatar == avatar ? 2 : 0)
                .frame(width: 66, height: 66)
        )
    }

    private func avatarSystemImage(_ avatar: String) -> String {
        switch avatar {
        case "robot": return "cpu.fill"
        case "rocket": return "arrowshape.up.fill"
        case "star": return "star.fill"
        case "planet": return "globe.fill"
        case "dinosaur": return "figure.walk"
        case "rainbow": return "sun.max.fill"
        case "unicorn": return "sparkles"
        case "astronaut": return "person.fill"
        default: return "star.fill"
        }
    }

    private func avatarColor(_ avatar: String) -> Color {
        switch avatar {
        case "robot": return CompanionPalette.novaBlue
        case "rocket": return CompanionPalette.novaPurple
        case "star": return CompanionPalette.novaYellow
        case "planet": return CompanionPalette.novaOrange
        case "dinosaur": return CompanionPalette.novaGreen
        case "rainbow": return CompanionPalette.novaPink
        case "unicorn": return CompanionPalette.novaPurple
        case "astronaut": return CompanionPalette.novaBlue
        default: return CompanionPalette.novaBlue
        }
    }

    private var buttonTitle: String {
        switch currentStep {
        case 0: return "Get Started"
        case 1: return "Continue"
        case 2: return "Start with Free"
        case 3: return "Explore Dashboard"
        default: return "Continue"
        }
    }

    private var isStepValid: Bool {
        switch currentStep {
        case 1: return !childName.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    private func continueAction() {
        if currentStep == 2 {
            isConnectingOAuth = true
            // Simulate OAuth connection
            oauthTask?.cancel()
            oauthTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard !Task.isCancelled else { return }
                isConnectingOAuth = false
                withAnimation { currentStep += 1 }
            }
        } else if currentStep < 3 {
            withAnimation { currentStep += 1 }
        } else {
            finishOnboarding()
        }
    }

    private func finishOnboarding() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

#Preview {
    CompanionOnboardingView()
}
