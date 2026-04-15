import SwiftUI
import NovaCore

/// Home screen for authenticated users.
///
/// Displays welcome greeting, featured lesson, learning paths, and progress overview.
/// Optimized for iPad with large touch targets.
public struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedLesson: Lesson?
    @State private var showFlipbook = false

    public var body: some View {
        NavigationStack {
            ZStack {
                NovaPalette.novaBackground
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Welcome header
                        WelcomeHeader(childName: viewModel.childName)

                        // Featured lesson card
                        if let featured = viewModel.featuredLesson {
                            NavigationLink(destination: {
                                FlipbookView(lesson: featured)
                            }) {
                                FeaturedLessonCard(lesson: featured) {
                                    showFlipbook = true
                                }
                            }
                        }

                        // Continue learning section
                        ContinueLearningSection(
                            currentLesson: viewModel.currentLesson,
                            progress: viewModel.progressPercentage
                        )

                        // Learning paths row
                        if !viewModel.learningPaths.isEmpty {
                            LearningPathRow(paths: viewModel.learningPaths)
                        }

                        // Quick stats
                        QuickStatsView()

                        Spacer(minLength: 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Nova Kids")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Quick stats view showing badges and achievements.
private struct QuickStatsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(NovaPalette.headingFont())
                .foregroundStyle(.primary)

            HStack(spacing: 12) {
                StatBadge(
                    icon: "star.fill",
                    value: "42",
                    label: "Points",
                    color: NovaPalette.novaYellow
                )

                StatBadge(
                    icon: "book.fill",
                    value: "6",
                    label: "Lessons Done",
                    color: NovaPalette.novaBlue
                )

                StatBadge(
                    icon: "flame.fill",
                    value: "3",
                    label: "Day Streak",
                    color: NovaPalette.novaOrange
                )
            }
        }
    }
}

/// Individual stat badge.
private struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            Text(value)
                .font(NovaPalette.smallHeadingFont())
                .foregroundStyle(.white)

            Text(label)
                .font(NovaPalette.captionFont())
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(color)
        .cornerRadius(12)
        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

#Preview {
    HomeView()
}
