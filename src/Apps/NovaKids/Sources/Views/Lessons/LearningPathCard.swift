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

    // S12-01: iPad-vs-iPhone path card width. Same logic as Home hero
    // tiles — path cards at 180pt read tiny on an iPad landscape carousel;
    // at 252pt they pace the row and leave the horizontal scroll feeling
    // deliberate instead of empty.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var cardWidth: CGFloat {
        horizontalSizeClass == .regular ? 252 : 180
    }

    // S12-03 contrast pair. `fg` pairs 1:1 with the rainbow `bg` so text,
    // icon, and progress bar all meet WCAG AA on every category. `.white`
    // only on purple — everything else gets dark navy. See
    // `NovaPalette.textOnPathColor(for:)` for the luminance math.
    private var bg: Color {
        NovaPalette.pathColor(for: path.id.uuidString)
    }
    private var fg: Color {
        NovaPalette.textOnPathColor(for: path.id.uuidString)
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(path.title)
                            .font(NovaPalette.smallHeadingFont())
                            .foregroundStyle(fg)
                            .lineLimit(2)

                        HStack(spacing: 4) {
                            Image(systemName: "book.fill")
                                .font(.caption)
                                .accessibilityHidden(true)

                            Text("\(lessonCount) lessons")
                                .font(NovaPalette.captionFont())
                        }
                        .foregroundStyle(fg.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: path.icon)
                        .font(NovaPalette.titleFont())
                        .foregroundStyle(fg)
                        .accessibilityHidden(true)
                }

                // Progress bar — track uses fg at low opacity so it reads as
                // a tint of the legible color rather than a foreign white
                // scrim, and the fill uses solid fg so the percentage bar
                // matches the text it describes.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(fg.opacity(0.3))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(fg)
                            .frame(
                                width: CGFloat(progress) * geo.size.width,
                                height: 8
                            )
                    }
                }
                .frame(height: 8)

                Text("\(Int(progress * 100))% complete")
                    .font(NovaPalette.captionFont())
                    .foregroundStyle(fg.opacity(0.8))
            }
            .padding(16)
            .background(bg)
            .cornerRadius(12)
            .frame(width: cardWidth)
            .shadow(color: bg.opacity(0.3), radius: 4, x: 0, y: 2)
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
