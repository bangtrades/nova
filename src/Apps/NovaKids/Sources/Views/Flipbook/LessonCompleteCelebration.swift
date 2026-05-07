import SwiftUI
import NovaCore

/// S13 — The dopamine moment. Lesson complete → confetti + trophy reveal.
///
/// Design beats (orchestrated via TimelineView phases for sequencing):
///   0.0s  — confetti bursts from top, starts falling
///   0.2s  — golden ring pulses out from center (BadgeUnlockBurst-style)
///   0.4s  — trophy art (lesson hero image) scales in with ease-out spring
///   0.7s  — "You earned!" headline slides in from above
///   1.0s  — trophy name + completion message fade in
///   1.3s  — "Continue" button slides up from bottom
///
/// Why a sheet/fullScreenCover instead of an inline overlay: the moment
/// is the focal interaction. Anything else on screen would dilute the
/// dopamine hit. fullScreenCover dims the parent and locks navigation
/// until the kid acknowledges by tapping Continue.
///
/// Reduce-motion path: confetti + scale-in + slide-in all degrade to
/// instant fade-in. The static composition still reads as celebration
/// — gold trophy frame, big text, single button — but no animations
/// fire. Per S11-16's celebration carve-out: ConfettiView's particles
/// are an explicit one-shot discrete-event survival exception, so
/// confetti does fire even under reduce-motion.
///
/// Audio: NovaHaptics `.success` ladder fires on appear. Future S14+
/// hook: VoiceManager could speak a Dashy-voiced "You did it!" line.
public struct LessonCompleteCelebration: View {
    /// Title of the completed lesson (cleaned of Wikipedia suffix etc.).
    let trophyName: String

    /// Hero image URL from the lesson's first card — shown as the
    /// trophy art inside a gold-bordered frame. Falls back to a
    /// gradient placeholder if nil (lesson without DALL-E assets).
    let heroImageURL: URL?

    /// Whether this is the kid's FIRST time completing this lesson.
    /// First-time gets full celebration; replays get a softer
    /// "Welcome back to X!" reaction with no confetti to avoid
    /// reward fatigue.
    let isFirstTime: Bool

    /// Tap-to-dismiss action.
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showConfetti = false
    @State private var showRing = false
    @State private var showTrophy = false
    @State private var showHeadline = false
    @State private var showName = false
    @State private var showButton = false

    public init(
        trophyName: String,
        heroImageURL: URL?,
        isFirstTime: Bool,
        onContinue: @escaping () -> Void
    ) {
        self.trophyName = trophyName
        self.heroImageURL = heroImageURL
        self.isFirstTime = isFirstTime
        self.onContinue = onContinue
    }

    public var body: some View {
        ZStack {
            // Chalkboard backdrop — anchors the moment in the classroom
            // metaphor instead of the legacy purple-ink gradient.
            chalkboardBackdrop
                .ignoresSafeArea()

            // Confetti only fires for first-time completions — replays
            // get the softer welcome-back beat without particle spam.
            if isFirstTime {
                ConfettiView(isActive: $showConfetti)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: Spacing.lg) {
                // Headline — slides in from above. Sun-yellow chalk-marker
                // text on the chalkboard with a soft ink shadow for legibility.
                Text(isFirstTime ? "You did it!" : "Welcome back!")
                    .font(NovaPalette.displayFont(size: 44, relativeTo: .largeTitle))
                    .foregroundStyle(NovaPalette.classroomSun)
                    .shadow(color: NovaPalette.classroomInk.opacity(0.45), radius: 4, y: 2)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : -30)
                    .accessibilityAddTraits(.isHeader)

                // Trophy + name sit together on a paper "achievement
                // certificate" card so the moment reads as a sticker /
                // trophy-shelf preview instead of a free-floating modal.
                VStack(spacing: Spacing.md) {
                    trophyFrame

                    VStack(spacing: 6) {
                        Text("You earned")
                            .font(NovaPalette.bodyFont())
                            .foregroundStyle(NovaPalette.classroomInk.opacity(0.7))

                        Text(trophyName)
                            .font(NovaPalette.displayFont(size: 28, relativeTo: .title))
                            .foregroundStyle(NovaPalette.classroomInk)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Spacing.lg)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("You earned the \(trophyName) trophy")
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
                .frame(maxWidth: 480)
                .background(
                    NovaPalette.classroomPaper,
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(NovaPalette.classroomInk.opacity(0.22), lineWidth: 2)
                )
                .overlay(alignment: .topTrailing) {
                    // Schoolhouse-red star "earned" sticker — used
                    // sparingly per the classroom palette guidance, only
                    // here as a tiny corner accent.
                    Image(systemName: "star.fill")
                        .font(.title2)
                        .foregroundStyle(NovaPalette.classroomSchoolRed)
                        .padding(10)
                        .background(
                            NovaPalette.classroomPaper,
                            in: Circle()
                        )
                        .overlay(
                            Circle()
                                .stroke(NovaPalette.classroomInk.opacity(0.28), lineWidth: 1.5)
                        )
                        .offset(x: 14, y: -14)
                        .accessibilityHidden(true)
                }
                .shadow(color: NovaPalette.classroomInk.opacity(0.28), radius: 18, y: 10)
                .opacity(showName ? 1 : 0)
                .offset(y: showName ? 0 : 20)

                Spacer(minLength: Spacing.lg)

                // Continue button — sunny yellow sticker capsule with
                // ink text. Preserves the existing primary CTA shape so
                // the button is still the obvious dismiss target.
                Button(action: onContinue) {
                    HStack(spacing: 10) {
                        Text("Continue")
                            .font(NovaPalette.headingFont())
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(NovaPalette.classroomInk)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(
                        Capsule(style: .continuous)
                            .fill(NovaPalette.classroomSun)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(NovaPalette.classroomInk.opacity(0.4), lineWidth: 2)
                    )
                    .shadow(color: NovaPalette.classroomInk.opacity(0.35), radius: 12, y: 4)
                }
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 40)
                .padding(.bottom, 40)
                .accessibilityHint("Dismisses the trophy celebration and returns to lessons")
            }
            .padding(.top, 60)
            .padding(.horizontal, Spacing.lg)
        }
        .onAppear {
            // Sequence the reveals — orchestrated for dopamine pacing.
            // Reduce-motion collapses every animation to instant.
            let stepDuration = reduceMotion ? 0.0 : 0.25

            withAnimation(.easeOut(duration: stepDuration)) {
                showConfetti = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.2)) {
                withAnimation(.easeOut(duration: stepDuration)) {
                    showRing = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.4)) {
                withAnimation(reduceMotion ? .none : .interpolatingSpring(stiffness: 180, damping: 14)) {
                    showTrophy = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.7)) {
                withAnimation(.easeOut(duration: stepDuration)) {
                    showHeadline = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 1.0)) {
                withAnimation(.easeOut(duration: stepDuration)) {
                    showName = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 1.3)) {
                withAnimation(.easeOut(duration: stepDuration)) {
                    showButton = true
                }
            }

            // Haptic on appear — S11-15 ladder
            NovaHaptics.success()
        }
    }

    /// Chalkboard backdrop — saturated classroom green anchor with a
    /// soft chalk-dust glow centered behind the certificate card.
    private var chalkboardBackdrop: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    NovaPalette.classroomChalkboard,
                    NovaPalette.classroomChalkboard.opacity(0.92)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                gradient: Gradient(colors: [
                    NovaPalette.classroomChalkDust.opacity(0.18),
                    Color.clear
                ]),
                center: .center,
                startRadius: 60,
                endRadius: 360
            )
            .accessibilityHidden(true)
        }
    }

    /// Golden sticker frame around the lesson hero image. Pulsing ring
    /// only renders when Reduce Motion is off.
    private var trophyFrame: some View {
        ZStack {
            // S11-07: BadgeUnlockBurst-style ring pulse (motion-gated).
            if reduceMotion == false {
                Circle()
                    .stroke(NovaPalette.classroomSun.opacity(0.4), lineWidth: 6)
                    .scaleEffect(showRing ? 1.4 : 0.6)
                    .opacity(showRing ? 0 : 0.8)
                    .animation(
                        .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                        value: showRing
                    )
                    .frame(width: 220, height: 220)
            }

            // Solid sun-yellow ring frame on the paper card.
            Circle()
                .stroke(NovaPalette.classroomSun, lineWidth: 8)
                .frame(width: 220, height: 220)
                .shadow(color: NovaPalette.classroomSun.opacity(0.55), radius: 16)

            // Trophy art — lesson's hero image, or sticker fallback.
            Group {
                if let url = heroImageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .empty, .failure:
                            trophyPlaceholder
                        @unknown default:
                            trophyPlaceholder
                        }
                    }
                } else {
                    trophyPlaceholder
                }
            }
            .frame(width: 200, height: 200)
            .clipShape(Circle())
        }
        .scaleEffect(showTrophy ? 1.0 : 0.3)
        .opacity(showTrophy ? 1 : 0)
    }

    private var trophyPlaceholder: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    NovaPalette.classroomSun,
                    NovaPalette.classroomSun.opacity(0.75)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "trophy.fill")
                .font(.system(size: 80))
                .foregroundStyle(NovaPalette.classroomInk)
                .accessibilityHidden(true)
        }
    }
}

#Preview("First-time celebration") {
    LessonCompleteCelebration(
        trophyName: "Sky Champion",
        heroImageURL: nil,
        isFirstTime: true,
        onContinue: { }
    )
}

#Preview("Replay celebration") {
    LessonCompleteCelebration(
        trophyName: "Sky Champion",
        heroImageURL: nil,
        isFirstTime: false,
        onContinue: { }
    )
}
