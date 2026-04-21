import SwiftUI
import NovaCore

/// Card representing a learning path in horizontal scroll.
///
/// Shows path icon, name, lesson count, and progress bar in a colorful card.
public struct LearningPathCard: View {
    /// The learning path to display.
    let path: LearningPath

    /// Number of lessons in this path.
    let lessonCount: Int

    /// Progress percentage (0-1).
    let progress: Double

    /// Callback when tapped.
    let onTap: () -> Void

    public init(
        path: LearningPath,
        lessonCount: Int = 0,
        progress: Double = 0,
        onTap: @escaping () -> Void
    ) {
        self.path = path
        self.lessonCount = lessonCount
        self.progress = progress
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(path.title)
                            .font(NovaPalette.smallHeadingFont())
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        HStack(spacing: 4) {
                            Image(systemName: "book.fill")
                                .font(.caption)
                                .accessibilityHidden(true)

                            Text("\(lessonCount) lessons")
                                .font(NovaPalette.captionFont())
                        }
                        .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: path.icon)
                        .font(NovaPalette.titleFont())
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }

                // Progress bar
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: CGFloat(progress) * 160, height: 8)
                }

                Text("\(Int(progress * 100))% complete")
                    .font(NovaPalette.captionFont())
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(16)
            .background(NovaPalette.pathColor(for: path.id.uuidString))
            .cornerRadius(12)
            .frame(width: 180)
            .shadow(color: NovaPalette.pathColor(for: path.id.uuidString).opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(path.title)
        .accessibilityValue("\(lessonCount) lessons, \(Int(progress * 100))% complete")
    }
}

#Preview {
    let path = LearningPath(
        id: UUID(),
        userId: UUID(),
        title: "What is AI?",
        description: "Learn the basics of artificial intelligence",
        color: "blue",
        icon: "brain.head.profile",
        sortOrder: 1,
        stage: .explorer,
        isPremium: false
    )

    VStack(spacing: 12) {
        LearningPathCard(path: path, lessonCount: 5, progress: 0.4) {
            print("Tapped")
        }

        LearningPathCard(path: path, lessonCount: 5, progress: 1.0) {
            print("Tapped")
        }
    }
    .padding(20)
}
