import SwiftUI

/// Trophies tab view — achievements and progress tracking.
///
/// Placeholder for future implementation of badges, achievements, and
/// learner progression display.
public struct TrophiesView: View {
    public var body: some View {
        NavigationStack {
            ZStack {
                NovaPalette.novaBackground
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Trophy mascot
                        VStack(spacing: 12) {
                            Image(systemName: "trophy.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(NovaPalette.novaYellow)

                            Text("Your Achievements")
                                .font(NovaPalette.headingFont())
                                .foregroundStyle(.primary)
                        }
                        .padding(.top, 24)

                        // Current stats
                        VStack(spacing: 16) {
                            StatRow(
                                icon: "star.fill",
                                label: "Total Points",
                                value: "42",
                                color: NovaPalette.novaYellow
                            )

                            StatRow(
                                icon: "book.fill",
                                label: "Lessons Completed",
                                value: "6",
                                color: NovaPalette.novaBlue
                            )

                            StatRow(
                                icon: "flame.fill",
                                label: "Learning Streak",
                                value: "3 days",
                                color: NovaPalette.novaOrange
                            )

                            StatRow(
                                icon: "target",
                                label: "Current Level",
                                value: "Explorer",
                                color: NovaPalette.novaPurple
                            )
                        }
                        .padding(20)
                        .background(NovaPalette.novaCardBackground)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                        // Badges section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Badges")
                                .font(NovaPalette.headingFont())
                                .foregroundStyle(.primary)

                            HStack(spacing: 16) {
                                BadgeCard(
                                    icon: "star.fill",
                                    title: "First Steps",
                                    color: NovaPalette.novaYellow,
                                    unlocked: true
                                )

                                BadgeCard(
                                    icon: "flame.fill",
                                    title: "On Fire",
                                    color: NovaPalette.novaOrange,
                                    unlocked: true
                                )

                                BadgeCard(
                                    icon: "book.fill",
                                    title: "Bookworm",
                                    color: NovaPalette.novaBlue,
                                    unlocked: false
                                )
                            }
                        }
                        .padding(20)
                        .background(NovaPalette.novaCardBackground)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                        Spacer(minLength: 24)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Trophies")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Single stat row in the achievements display.
private struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

/// Badge card showing achievement status.
private struct BadgeCard: View {
    let icon: String
    let title: String
    let color: Color
    let unlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(unlocked ? 1.0 : 0.2))

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(unlocked ? .white : color.opacity(0.4))
            }
            .frame(width: 64, height: 64)

            Text(title)
                .font(NovaPalette.smallHeadingFont())
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if !unlocked {
                Text("Locked")
                    .font(NovaPalette.captionFont())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .opacity(unlocked ? 1.0 : 0.6)
    }
}

#Preview {
    TrophiesView()
}
