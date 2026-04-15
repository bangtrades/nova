import SwiftUI
import NovaCore

/// Reusable badge tile component.
///
/// Displays earned badges with full color and glow, or locked badges with grayscale and lock icon.
/// Includes progress indicator for partially earned badges.
public struct BadgeView: View {
    let earned: Bool
    let badge: Badge
    let progress: Float
    let earnedDate: Date?

    @State private var showSparkle = false
    @State private var sparkleTask: Task<Void, Never>?

    public init(
        earned: Bool,
        badge: Badge,
        progress: Float = 0,
        earnedDate: Date? = nil
    ) {
        self.earned = earned
        self.badge = badge
        self.progress = progress
        self.earnedDate = earnedDate
    }

    public var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Badge background circle
                Circle()
                    .fill(
                        earned
                            ? LinearGradient(
                                gradient: Gradient(colors: [
                                    NovaPalette.novaYellow,
                                    NovaPalette.novaOrange,
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.gray.opacity(0.2),
                                    Color.gray.opacity(0.1),
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )

                // Glow effect for earned badges
                if earned {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    NovaPalette.novaYellow.opacity(0.3),
                                    Color.clear,
                                ]),
                                center: .center,
                                startRadius: 50,
                                endRadius: 80
                            )
                        )
                        .blur(radius: 8)
                }

                VStack(spacing: 8) {
                    // Badge icon
                    if earned {
                        Image(systemName: badge.icon)
                            .font(.largeTitle.weight(.semibold))
                            .foregroundStyle(.white)
                    } else {
                        ZStack {
                            Image(systemName: badge.icon)
                                .font(.largeTitle.weight(.semibold))
                                .foregroundStyle(Color.gray.opacity(0.3))

                            // Lock icon overlay
                            Image(systemName: "lock.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.gray)
                                .offset(x: 20, y: 20)
                        }
                    }

                    // Question mark for locked badges
                    if !earned {
                        Text("???")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.gray.opacity(0.4))
                    }
                }

                // Sparkle effect on first appearance
                if earned && showSparkle {
                    Image(systemName: "star.fill")
                        .font(.body)
                        .foregroundStyle(NovaPalette.novaBlue)
                        .offset(x: -30, y: -30)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 120, height: 120)
            .onAppear {
                if earned {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        showSparkle = true
                    }
                    sparkleTask = Task {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        guard !Task.isCancelled else { return }
                        showSparkle = false
                    }
                }
            }

            // Badge name
            Text(badge.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 40)

            // Progress or earned date
            if earned {
                if let earnedDate = earnedDate {
                    Text(formatDate(earnedDate))
                        .font(NovaPalette.captionFont())
                        .foregroundStyle(.secondary)
                } else {
                    Text("Earned!")
                        .font(NovaPalette.captionFont())
                        .foregroundStyle(NovaPalette.novaGreen)
                }
            } else {
                // Progress bar for locked badges
                VStack(spacing: 4) {
                    ProgressView(value: Double(progress))
                        .tint(NovaPalette.novaBlue)
                        .frame(height: 6)

                    Text("\(Int(progress * 100))%")
                        .font(NovaPalette.captionFont())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 140)
        .padding(12)
        .background(
            earned
                ? NovaPalette.novaYellow.opacity(0.1)
                : Color.gray.opacity(0.05)
        )
        .cornerRadius(12)
        .onDisappear {
            sparkleTask?.cancel()
        }
        .accessibilityLabel(badge.title)
        .accessibilityValue(earned ? "Earned" : "Locked - \(Int(progress * 100))% progress")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 12) {
            BadgeView(
                earned: true,
                badge: Badge(
                    id: UUID(),
                    title: "First Lesson",
                    description: "Complete your first lesson",
                    icon: "book.circle.fill",
                    criteria: BadgeCriteria(type: .lessonsCompleted, count: 1)
                ),
                earnedDate: Date().addingTimeInterval(-86400 * 3)
            )

            BadgeView(
                earned: false,
                badge: Badge(
                    id: UUID(),
                    title: "Voice Adventurer",
                    description: "Record 5 voice responses",
                    icon: "mic.circle.fill",
                    criteria: BadgeCriteria(type: .voiceInteractions, count: 5)
                ),
                progress: 0.6
            )
        }

        HStack(spacing: 12) {
            BadgeView(
                earned: true,
                badge: Badge(
                    id: UUID(),
                    title: "3-Day Streak",
                    description: "Learn for 3 days",
                    icon: "flame.circle.fill",
                    criteria: BadgeCriteria(type: .daysStreak, count: 3)
                ),
                earnedDate: Date().addingTimeInterval(-86400)
            )

            BadgeView(
                earned: false,
                badge: Badge(
                    id: UUID(),
                    title: "AI Genius",
                    description: "Complete AI Basics path",
                    icon: "sparkles",
                    criteria: BadgeCriteria(type: .pathCompleted, count: 1)
                ),
                progress: 0.4
            )
        }
    }
    .padding()
    .background(NovaPalette.novaBackground)
}
