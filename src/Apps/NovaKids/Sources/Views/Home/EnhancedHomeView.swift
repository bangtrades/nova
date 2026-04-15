import SwiftUI
import NovaCore
import NovaVoice

/// Polished home screen with learning path sections, progress tracking, and time-based greetings.
///
/// Displays horizontal scroll sections by learning path, stage badge, continue learning hero,
/// and personalized greeting. Supports pull-to-refresh for syncing.
public struct EnhancedHomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedLesson: Lesson?
    @State private var showFlipbook = false
    @State private var isRefreshing = false

    public var body: some View {
        NavigationStack {
            ZStack {
                NovaPalette.novaBackground
                    .ignoresSafeArea()

                if viewModel.learningPaths.isEmpty && viewModel.allLessons.isEmpty {
                    // Empty state for new users
                    emptyStateView()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 24) {
                            // Greeting header
                            greetingHeader()

                            // Stage badge
                            stageBadge()

                            // Continue learning hero
                            if let currentLesson = viewModel.currentLesson {
                                ContinueLearningSection(
                                    currentLesson: currentLesson,
                                    progress: viewModel.progressPercentage
                                )
                                .padding(.horizontal, 20)
                            }

                            // Learning path sections
                            if !viewModel.learningPaths.isEmpty {
                                ForEach(viewModel.learningPaths) { path in
                                    learningPathSection(path)
                                }
                            }

                            Spacer(minLength: 20)
                        }
                        .padding(.vertical, 20)
                    }
                    .refreshable {
                        await performRefresh()
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Subviews

    private func greetingHeader() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timeBasedGreeting())
                .font(NovaPalette.titleFont())
                .foregroundStyle(.primary)

            Text("Ready to learn something awesome today?")
                .font(NovaPalette.bodyFont())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private func stageBadge() -> some View {
        HStack(spacing: 12) {
            // Stage icon
            Image(systemName: stageIcon())
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            // Stage label
            VStack(alignment: .leading, spacing: 2) {
                Text("Learning Stage")
                    .font(NovaPalette.captionFont())
                    .foregroundStyle(.white.opacity(0.8))

                Text(stageLabel())
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(.white)
            }

            Spacer()

            // Progress indicator
            Text("\(viewModel.progressPercentage.rounded())%")
                .font(NovaPalette.headingFont())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    NovaPalette.novaBlue,
                    NovaPalette.novaPurple
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }

    private var lessonsByPath: [UUID: [Lesson]] {
        Dictionary(grouping: viewModel.allLessons.filter { $0.pathId != nil }, by: { $0.pathId! })
    }

    private func learningPathSection(_ path: LearningPath) -> some View {
        let pathLessons = lessonsByPath[path.id] ?? []

        return VStack(alignment: .leading, spacing: 12) {
            // Section header with progress
            VStack(alignment: .leading, spacing: 8) {
                Text(path.title)
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text("3 of 8 lessons")
                        .font(NovaPalette.captionFont())
                        .foregroundStyle(.secondary)

                    ProgressView(value: 0.375)
                        .tint(NovaPalette.pathColor(for: path.id.uuidString))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 20)

            // Horizontal scroll of lessons
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(pathLessons) { lesson in
                        NavigationLink(destination: {
                            FlipbookView(lesson: lesson)
                        }) {
                            lessonCard(lesson, pathColor: NovaPalette.pathColor(for: path.id.uuidString))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollTargetBehavior(.viewAligned)
        }
        .padding(.vertical, 12)
    }

    private func lessonCard(_ lesson: Lesson, pathColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top-left stage badge
            HStack {
                stageTagView(for: lesson)
                Spacer()
            }

            Spacer()

            // Lesson title
            Text(lesson.title)
                .font(NovaPalette.smallHeadingFont())
                .foregroundStyle(.primary)
                .lineLimit(2)

            // Progress dots
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(index == 0 ? pathColor : Color.gray.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
                Spacer()
            }
        }
        .padding(12)
        .frame(width: 140, height: 160)
        .background(NovaPalette.novaCardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func stageTagView(for lesson: Lesson) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            Text("Explorer")
                .font(NovaPalette.captionFont())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(NovaPalette.novaYellow)
        .cornerRadius(4)
    }

    private func emptyStateView() -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "book.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(NovaPalette.novaBlue)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Welcome! Let's start exploring AI together!")
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(.primary)

                Text("Choose your first learning path to begin your adventure.")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)

            Button(action: {}) {
                Text("Browse Learning Paths")
                    .font(NovaPalette.smallHeadingFont())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(NovaPalette.novaBlue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func timeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<12:
            return "Good morning!"
        case 12..<17:
            return "Good afternoon!"
        default:
            return "Good evening!"
        }
    }

    private func stageLabel() -> String {
        // Map progress to stage
        let percentage = viewModel.progressPercentage
        switch percentage {
        case 0..<25:
            return "Explorer"
        case 25..<50:
            return "Thinker"
        case 50..<75:
            return "Maker"
        default:
            return "Creator"
        }
    }

    private func stageIcon() -> String {
        // Map progress to stage icon
        let percentage = viewModel.progressPercentage
        switch percentage {
        case 0..<25:
            return "binoculars.fill"
        case 25..<50:
            return "lightbulb.fill"
        case 50..<75:
            return "hammer.fill"
        default:
            return "sparkles"
        }
    }

    private func performRefresh() async {
        isRefreshing = true
        // Trigger view model refresh
        viewModel.refresh()
        // Wait briefly for refresh to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isRefreshing = false
    }
}

#Preview {
    EnhancedHomeView()
        .environmentObject(VoiceManager(speechSynthesizer: SpeechSynthesizer()))
}
