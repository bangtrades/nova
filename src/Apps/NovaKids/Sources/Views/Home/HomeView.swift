import SwiftUI
import NovaCore

/// Home screen for authenticated users.
///
/// Displays welcome greeting, featured lesson, continue-learning block,
/// learning paths, and a quick-stats row. Optimized for iPad with large
/// touch targets. As of S11-05 the screen is built from the S11-03 design
/// system primitives — `NovaCard` for surfaces, Bangers via
/// `NovaPalette.displayFont(size:)` for headlines, and `Spacing.*` for
/// consistent vertical rhythm.
public struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                NovaPalette.novaBackground
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        WelcomeHeader(childName: viewModel.childName)

                        // Featured lesson — NavigationLink owns the tap so
                        // the card itself stays "content, not control".
                        if let featured = viewModel.featuredLesson {
                            NavigationLink {
                                FlipbookView(lesson: featured)
                            } label: {
                                FeaturedLessonCard(lesson: featured)
                            }
                            .buttonStyle(.plain)
                        }

                        ContinueLearningSection(
                            currentLesson: viewModel.currentLesson,
                            progress: viewModel.progressPercentage
                        )

                        if !viewModel.learningPaths.isEmpty {
                            LearningPathRow(paths: viewModel.learningPaths)
                        }

                        QuickStatsView()

                        Spacer(minLength: Spacing.lg)
                    }
                    .padding(Spacing.lg)
                }
            }
            .navigationTitle("Nova Kids")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Quick stats row showing badges and achievements.
///
/// Each `StatBadge` keeps its per-metric color fill (points = sun, lessons =
/// blue, streak = orange) but adopts the `NovaCard` visual language
/// underneath: 20pt corner radius + 2pt ink stroke + paper shadow. The
/// colored fill stays because that's how a kid tells at a glance which
/// number means what.
private struct QuickStatsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm + 4) {
            Text("Achievements")
                .font(NovaPalette.displayFont(size: 24))
                .foregroundStyle(NovaPalette.ink)

            HStack(spacing: Spacing.sm + 4) {
                StatBadge(
                    icon: "star.fill",
                    value: "42",
                    label: "Points",
                    tint: NovaPalette.sun
                )

                StatBadge(
                    icon: "book.fill",
                    value: "6",
                    label: "Lessons Done",
                    tint: NovaPalette.Category.blue
                )

                StatBadge(
                    icon: "flame.fill",
                    value: "3",
                    label: "Day Streak",
                    tint: NovaPalette.Category.orange
                )
            }
        }
    }
}

/// Individual stat tile — keeps its category tint as the fill, adopts NovaCard's
/// stroke + radius language so the row sits visually in the same family as
/// the rest of the screen.
private struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    private let cornerRadius: CGFloat = 20

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(NovaPalette.ink)
                .accessibilityHidden(true)

            Text(value)
                .font(NovaPalette.displayFont(size: 28))
                .foregroundStyle(NovaPalette.ink)

            Text(label)
                .font(NovaPalette.captionFont())
                .foregroundStyle(NovaPalette.ink.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(
            tint,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(NovaPalette.ink, lineWidth: 2)
        }
        .shadow(color: NovaPalette.ink.opacity(0.08), radius: 6, x: 0, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

#Preview {
    HomeView()
}
