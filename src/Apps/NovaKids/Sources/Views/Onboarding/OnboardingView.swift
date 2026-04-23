import SwiftUI
import NovaCore

/// Kid-friendly onboarding flow shown once on first launch.
///
/// Walks through 4 pages: Meet Dashy, Choose Avatar, Enter Name, and First Mission.
/// Uses TabView with PageTabViewStyle for swiping between pages.
/// Tracks completion via @AppStorage("hasCompletedOnboarding").
public struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false

    // Reduce-motion: gates the Dashy intro bob/hand-wave and the page-transition
    // `withAnimation` calls. Confetti is kept on the final "Let's Go!" tap as a
    // single celebratory event (not a repeating animation) — that's the one
    // deliberate carve-out from the reduce-motion audit since it's
    // crossing-the-finish-line feedback, not ambient motion.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentPage: Int = 0
    @State private var selectedAvatar: AvatarOption = .robot
    @State private var childName: String = ""
    @State private var showConfetti: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            // S11-17: `.page` over `novaBackground` so the screen-flip inherits
            // the adaptive ink/page pair in dark mode instead of the old
            // near-white fallback.
            NovaPalette.page
                .ignoresSafeArea()

            TabView(selection: $currentPage) {
                // Page 1: Meet Dashy
                onboardingPage { meetDashyPage() }
                    .tag(0)

                // Page 2: Choose Avatar
                onboardingPage { chooseAvatarPage() }
                    .tag(1)

                // Page 3: Enter Name
                onboardingPage { enterNamePage() }
                    .tag(2)

                // Page 4: First Mission
                onboardingPage { firstMissionPage() }
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

    // MARK: - iPad width cap
    //
    // S12-01: Onboarding copy is a letter to the child, not a dashboard.
    // On iPhone the 390pt viewport already paces the sentences; on iPad
    // landscape (1366pt) we need to cap the page at a reading measure so
    // the copy doesn't stretch into a 14-word line. Double-frame pattern —
    // `.frame(maxWidth: 600)` caps the content, then `.frame(maxWidth:
    // .infinity)` claims the parent's full width so the capped content
    // centers inside it. On compact size class the first frame is a no-op
    // (parent width < 600), so the phone layout is unchanged.
    @ViewBuilder
    private func onboardingPage<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Page Views

    /// Dashy intro animation values. Pre-computed per-frame by `meetDashyPage`
    /// under `TimelineView(.animation)`, or frozen at their neutral resting
    /// pose when reduce-motion is enabled.
    private struct DashyIdlePose {
        let headBob: CGFloat
        let eyePulse: Double
        let eyePulseOffset: Double
        let handAngle: Double

        static let rest = DashyIdlePose(headBob: 0, eyePulse: 1.0, eyePulseOffset: 1.0, handAngle: 0)
    }

    @ViewBuilder
    private func meetDashyPage() -> some View {
        // S11-17: Dashy's idle bob is driven by `TimelineView(.animation)` —
        // the old code used `sin(Date().timeIntervalSince1970)` inline in view
        // bodies, which only evaluates once per SwiftUI body refresh, so the
        // "idle bounce" was silently a still pose.
        //
        // Reduce-motion: branched at the view-builder level rather than on
        // TimelineView's schedule. Two reasons: (1) `ExplicitTimelineSchedule`
        // and `AnimationTimelineSchedule` are distinct concrete types, so a
        // ternary on `.animation` vs `.explicit` breaks `TimelineView`'s
        // generic `Schedule: TimelineSchedule` constraint; (2) skipping
        // TimelineView entirely under reduce-motion avoids the per-frame
        // redraw tick on devices where the user has opted out of motion.
        //
        // Dashy body colour: novaPurple stays (it's the Dashy identity colour,
        // promoted to a character attribute in S11-10, not a rainbow pick).
        // The waving-hand icon flips from novaYellow → sun so the "Dashy body"
        // accent lands on a 3+1 palette tint.
        if reduceMotion {
            dashyPageContent(pose: .rest)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let pose = DashyIdlePose(
                    headBob: CGFloat(sin(t) * 4),
                    eyePulse: 1.0 + (sin(t * 2) * 0.1),
                    eyePulseOffset: 1.0 + (sin(t * 2 + 0.2) * 0.1),
                    handAngle: sin(t * 1.5) * 25
                )
                dashyPageContent(pose: pose)
            }
        }
    }

    private func dashyPageContent(pose: DashyIdlePose) -> some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Animated Dashy character
            VStack(spacing: 0) {
                // Dashy head (purple circle with simple features)
                ZStack {
                    Circle()
                        .fill(NovaPalette.novaPurple)
                        .frame(width: 120, height: 120)

                    HStack(spacing: Spacing.lg) {
                        // Left eye
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .scaleEffect(pose.eyePulse)

                        // Right eye
                        Circle()
                            .fill(Color.white)
                            .frame(width: 16, height: 16)
                            .scaleEffect(pose.eyePulseOffset)
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
                .offset(y: pose.headBob)

                // Waving hand (circle with motion). Sun accent replaces the
                // legacy novaYellow so the wave reads as the same 3+1 palette
                // as the rest of the app.
                ZStack {
                    Circle()
                        .fill(NovaPalette.novaPurple)
                        .frame(width: 40, height: 40)
                        .offset(x: 45, y: -25)

                    Image(systemName: "hand.raised.fill")
                        .font(NovaPalette.titleFont())
                        .foregroundStyle(NovaPalette.sun)
                        .offset(x: 45, y: -25)
                        .rotation3DEffect(
                            .degrees(pose.handAngle),
                            axis: (x: 0, y: 1, z: 0)
                        )
                }
            }
            .frame(height: 180)

            Spacer()

            // Text
            VStack(spacing: Spacing.sm + Spacing.xs) {
                Text("Meet Dashy!")
                    .font(NovaPalette.titleFont())
                    .foregroundStyle(.primary)

                Text("Hi! I'm Dashy, your AI buddy!")
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()

            // Next button — routed through the shared DS primary style so the
            // ink-outline / press-scale / commit-haptic vocabulary matches
            // every other primary CTA in the app.
            Button(action: { transitionToPage(1) }) {
                Text("Next")
            }
            .novaPrimary()
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xl)
            .accessibilityLabel("Next button")
        }
    }

    private func chooseAvatarPage() -> some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.sm) {
                Text("Choose Your Look!")
                    .font(NovaPalette.titleFont())
                    .foregroundStyle(.primary)

                Text("Pick your favorite character!")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, Spacing.xl)
            .padding(.horizontal, Spacing.lg)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Spacing.md) {
                    // Grid of avatars (2 columns)
                    ForEach(Array(AvatarOption.allCases.enumerated()), id: \.offset) { index, avatar in
                        if index % 2 == 0 {
                            HStack(spacing: Spacing.md) {
                                avatarButton(avatar)

                                if index + 1 < AvatarOption.allCases.count {
                                    avatarButton(AvatarOption.allCases[index + 1])
                                } else {
                                    Spacer()
                                }
                            }
                            .padding(.horizontal, Spacing.lg)
                        }
                    }
                }
                .padding(.vertical, Spacing.sm + Spacing.xs)
            }

            HStack(spacing: Spacing.sm + Spacing.xs) {
                Button(action: { transitionToPage(0) }) {
                    Text("Back")
                }
                .novaSecondary()

                Button(action: { transitionToPage(2) }) {
                    Text("Next")
                }
                .novaPrimary()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
    }

    private func avatarButton(_ avatar: AvatarOption) -> some View {
        Button(action: {
            selectedAvatar = avatar
            // S11-15: avatar selection is an acknowledgement (tap beat),
            // not a commitment — confirmation happens when the user proceeds.
            NovaHaptics.tap()
        }) {
            VStack(spacing: Spacing.sm + Spacing.xs) {
                Image(systemName: avatar.systemImageName)
                    .font(.largeTitle)
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(avatar.backgroundColor)
                    .cornerRadius(12)
                    // Selected-state scale bump is an instant state change
                    // (no withAnimation wrapper), so it respects reduce-motion
                    // implicitly — there's no animation to suppress.
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
        VStack(spacing: Spacing.xl) {
            VStack(spacing: Spacing.sm) {
                Text("What's Your Name?")
                    .font(NovaPalette.titleFont())
                    .foregroundStyle(.primary)

                Text("Let Dashy know how to say hello!")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, Spacing.xl)
            .padding(.horizontal, Spacing.lg)

            Spacer()

            // Large name input
            TextField("Type your name here...", text: $childName)
                .font(NovaPalette.titleFont())
                .multilineTextAlignment(.center)
                .padding(.vertical, Spacing.lg)
                .padding(.horizontal, Spacing.lg)
                .background(NovaPalette.novaCardBackground)
                .cornerRadius(12)
                .frame(minHeight: 60)
                .padding(.horizontal, Spacing.lg)
                .accessibilityLabel("Name input field")

            Spacer()

            HStack(spacing: Spacing.sm + Spacing.xs) {
                Button(action: { transitionToPage(1) }) {
                    Text("Back")
                }
                .novaSecondary()

                Button(action: { transitionToPage(3) }) {
                    Text("Next")
                }
                .novaPrimary()
                .disabled(childName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
    }

    private func firstMissionPage() -> some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.sm) {
                Text("Your First Mission!")
                    .font(NovaPalette.titleFont())
                    .foregroundStyle(.primary)
            }
            .padding(.top, Spacing.xl)

            Spacer()

            // Mini-lesson card. Lightbulb foreground flips to `.sun` so the
            // card reads on-palette without the legacy novaYellow literal.
            VStack(spacing: Spacing.md) {
                Image(systemName: "lightbulb.fill")
                    .font(.largeTitle)
                    .foregroundStyle(NovaPalette.sun)

                Text("What is AI?")
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(.primary)

                Text("AI is like a smart helper that learns from examples!")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .padding(Spacing.lg)
            .background(NovaPalette.novaCardBackground)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .padding(.horizontal, Spacing.lg)

            Spacer()

            HStack(spacing: Spacing.sm + Spacing.xs) {
                Button(action: { transitionToPage(2) }) {
                    Text("Back")
                }
                .novaSecondary()

                // Finale button. Previously a hand-rolled orange→purple
                // gradient meant to celebrate "you made it"; the confetti is
                // the celebration now, and the button stays on the shared DS
                // primary style so every "commit" moment in the app uses the
                // same tactile vocabulary (coral fill + ink outline +
                // commit haptic via NovaPrimaryButtonStyle).
                Button(action: {
                    hasCompletedOnboarding = true
                    // Confetti is the one celebration we keep regardless of
                    // reduce-motion — it's a single one-shot event, not
                    // ambient motion, and marks crossing-the-finish-line.
                    withAnimation { showConfetti = true }
                }) {
                    Text("Let's Go!")
                }
                .novaPrimary()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
        }
    }

    // MARK: - Page transition helper
    //
    // Single entry point for advancing pages so the reduce-motion check lives
    // in one place instead of being smeared across every Back/Next button. Under
    // reduce-motion the page just snaps into view — TabView's .page style
    // still honors system preferences for its own gesture-driven swipes, this
    // only controls the button-driven hop.
    private func transitionToPage(_ page: Int) {
        if reduceMotion {
            currentPage = page
        } else {
            withAnimation { currentPage = page }
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
