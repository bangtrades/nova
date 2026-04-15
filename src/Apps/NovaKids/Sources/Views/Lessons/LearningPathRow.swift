import SwiftUI
import NovaCore

/// Horizontal scrollable row of learning path cards.
///
/// Displays paths in a snap-scrolling carousel with filtering capability.
public struct LearningPathRow: View {
    /// Learning paths to display.
    let paths: [LearningPath]

    @State private var selectedPath: LearningPath?

    public init(paths: [LearningPath]) {
        self.paths = paths
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Learning Paths")
                .font(NovaPalette.headingFont())
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(paths) { path in
                        LearningPathCard(
                            path: path,
                            lessonCount: Int.random(in: 3...8),
                            progress: Double.random(in: 0...1)
                        ) {
                            selectedPath = path
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .scrollTargetBehavior(.viewAligned)

            if let selected = selectedPath {
                Text("Filtered: \(selected.title)")
                    .font(NovaPalette.captionFont())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Learning Paths")
    }
}

#Preview {
    let paths = [
        LearningPath(
            id: UUID(),
            userId: UUID(),
            title: "What is AI?",
            description: "Learn the basics",
            color: "blue",
            icon: "brain.head.profile",
            sortOrder: 1,
            stage: .explorer,
            isPremium: false
        ),
        LearningPath(
            id: UUID(),
            userId: UUID(),
            title: "How Computers Think",
            description: "Understand logic",
            color: "orange",
            icon: "cpu",
            sortOrder: 2,
            stage: .explorer,
            isPremium: false
        ),
        LearningPath(
            id: UUID(),
            userId: UUID(),
            title: "Talk to Robots",
            description: "Communicate",
            color: "purple",
            icon: "bubble.left.and.bubble.right.fill",
            sortOrder: 3,
            stage: .thinker,
            isPremium: true
        ),
    ]

    LearningPathRow(paths: paths)
        .padding(20)
}
