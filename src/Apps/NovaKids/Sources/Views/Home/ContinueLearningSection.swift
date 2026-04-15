import SwiftUI
import NovaCore

/// Section showing current learning progress.
///
/// Displays the current lesson, progress bar, and time spent today.
public struct ContinueLearningSection: View {
    /// The current lesson being worked on.
    let currentLesson: Lesson?

    /// Progress percentage (0-1).
    let progress: Double

    public init(currentLesson: Lesson?, progress: Double) {
        self.currentLesson = currentLesson
        self.progress = progress
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Continue Learning")
                .font(NovaPalette.headingFont())
                .foregroundStyle(.primary)

            if let lesson = currentLesson {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.title)
                                .font(NovaPalette.smallHeadingFont())
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            Text("\(Int(progress * 100))% complete")
                                .font(NovaPalette.captionFont())
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("→")
                            .font(NovaPalette.headingFont())
                            .foregroundStyle(NovaPalette.novaOrange)
                    }

                    // Progress bar
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.25))
                            .frame(height: 12)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        NovaPalette.novaGreen,
                                        NovaPalette.novaBlue,
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: CGFloat(progress) * 280, height: 12)
                    }
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                                .foregroundStyle(NovaPalette.novaBlue)
                                .accessibilityHidden(true)

                            Text("12 min today")
                                .font(NovaPalette.captionFont())
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("12 minutes spent today")

                        Spacer()

                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundStyle(NovaPalette.novaOrange)
                                .accessibilityHidden(true)

                            Text("3 day streak")
                                .font(NovaPalette.captionFont())
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("3 day learning streak")
                    }
                }
                .padding(16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            NovaPalette.novaBlue.opacity(0.08),
                            NovaPalette.novaGreen.opacity(0.08),
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
            } else {
                Text("No lesson in progress")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Continue Learning")
        .accessibilityValue(currentLesson.map { "\($0.title), \(Int(progress * 100))% complete" } ?? "No lesson in progress")
    }
}

#Preview {
    let lesson = Lesson(
        id: UUID(),
        pathId: UUID(),
        userId: UUID(),
        title: "What Makes AI Smart?",
        description: "Learn how artificial intelligence learns from data",
        thumbnailURL: nil,
        difficulty: 1,
        sourceURL: nil,
        aiAnalysis: nil,
        status: .published,
        sortOrder: 1,
        createdAt: Date(),
        publishedAt: Date(),
        cards: []
    )

    VStack(spacing: 20) {
        ContinueLearningSection(currentLesson: lesson, progress: 0.35)
        ContinueLearningSection(currentLesson: nil, progress: 0)
    }
    .padding(20)
}
