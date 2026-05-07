import SwiftUI
import NovaCore

/// Large classroom book object for launching one lesson from the bookshelf.
public struct ClassroomLessonBookButton: View {
    private let lesson: Lesson
    private let pathTitle: String?
    private let bookColor: Color
    private let isCompleted: Bool
    private let isNewOverride: Bool?
    private let onSelectLesson: (Lesson) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressing = false

    public init(
        lesson: Lesson,
        pathTitle: String?,
        bookColor: Color,
        isCompleted: Bool = false,
        isNewOverride: Bool? = nil,
        onSelectLesson: @escaping (Lesson) -> Void
    ) {
        self.lesson = lesson
        self.pathTitle = pathTitle
        self.bookColor = bookColor
        self.isCompleted = isCompleted
        self.isNewOverride = isNewOverride
        self.onSelectLesson = onSelectLesson
    }

    public var body: some View {
        Button {
            onSelectLesson(lesson)
        } label: {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                bookTop

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(shortTitle)
                        .font(NovaPalette.smallHeadingFont())
                        .foregroundStyle(NovaPalette.classroomPaper)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.leading)

                    if let pathTitle {
                        Text(pathTitle)
                            .font(NovaPalette.captionFont())
                            .foregroundStyle(NovaPalette.classroomPaper.opacity(0.82))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }

                Spacer(minLength: Spacing.sm)

                difficultyMarks
            }
            .padding(Spacing.md)
            .frame(width: 148, alignment: .topLeading)
            .frame(minHeight: 184, alignment: .topLeading)
            .background(bookShape)
            .overlay(bookSpine, alignment: .leading)
            .overlay(bookHighlight, alignment: .topTrailing)
            .overlay(alignment: .bottomTrailing) {
                if isCompleted {
                    completedBadge
                        .padding(Spacing.sm)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(minWidth: 148, minHeight: 184)
        .scaleEffect(isPressing && reduceMotion == false ? 0.97 : 1.0)
        .animation(reduceMotion ? .none : .easeOut(duration: 0.12), value: isPressing)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if isPressing == false {
                        isPressing = true
                    }
                }
                .onEnded { _ in
                    isPressing = false
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens this lesson.")
        .accessibilityAddTraits(.isButton)
    }

    private var bookTop: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "book.closed.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(NovaPalette.classroomPaper)
                .accessibilityHidden(true)

            Spacer(minLength: Spacing.sm)

            if isNew {
                Text("NEW")
                    .font(NovaPalette.captionFont().weight(.bold))
                    .foregroundStyle(NovaPalette.classroomInk)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        Capsule(style: .continuous)
                            .fill(NovaPalette.classroomSun)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(NovaPalette.classroomInk, lineWidth: 1.5)
                    )
                    .accessibilityHidden(true)
            }
        }
    }

    private var difficultyMarks: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < normalizedDifficulty ? NovaPalette.classroomSun : NovaPalette.classroomPaper.opacity(0.45))
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(NovaPalette.classroomInk.opacity(0.45), lineWidth: 1)
                    )
                    .accessibilityHidden(true)
            }
        }
    }

    private var completedBadge: some View {
        ZStack {
            Circle()
                .fill(NovaPalette.classroomSun)
                .overlay {
                    Circle()
                        .stroke(NovaPalette.classroomInk, lineWidth: 2)
                }

            Image(systemName: "checkmark")
                .font(.caption.weight(.black))
                .foregroundStyle(NovaPalette.classroomInk)
                .accessibilityHidden(true)
        }
        .frame(width: 34, height: 34)
        .shadow(color: NovaPalette.classroomInk.opacity(0.18), radius: 2, x: 0, y: 1)
        .accessibilityHidden(true)
    }

    private var bookShape: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(bookColor)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(NovaPalette.classroomInk, lineWidth: 2)
            )
            .shadow(color: NovaPalette.classroomInk.opacity(0.16), radius: 5, x: 0, y: 3)
    }

    private var bookSpine: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(NovaPalette.classroomInk.opacity(0.18))
            .frame(width: 18)
            .padding(.vertical, 6)
            .padding(.leading, 6)
            .accessibilityHidden(true)
    }

    private var bookHighlight: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(NovaPalette.classroomPaper.opacity(0.22))
            .frame(width: 24, height: 80)
            .padding(.top, Spacing.md)
            .padding(.trailing, Spacing.md)
            .accessibilityHidden(true)
    }

    private var shortTitle: String {
        lesson.title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedDifficulty: Int {
        min(max(lesson.difficulty, 1), 3)
    }

    private var isNew: Bool {
        if let isNewOverride {
            return isNewOverride
        }
        guard let publishedAt = lesson.publishedAt else { return false }
        let sevenDays: TimeInterval = 7 * 24 * 60 * 60
        return Date().timeIntervalSince(publishedAt) < sevenDays
    }

    private var accessibilityLabel: String {
        let states = [
            isNew ? "new" : nil,
            isCompleted ? "completed" : nil,
        ].compactMap { $0 }

        let stateText = states.isEmpty ? "" : ", \(states.joined(separator: ", "))"
        if let pathTitle {
            return "\(lesson.title), \(pathTitle) lesson\(stateText)"
        }
        return "\(lesson.title), lesson\(stateText)"
    }
}

#Preview {
    let pathId = UUID()
    let userId = UUID()
    let lesson = Lesson(
        pathId: pathId,
        userId: userId,
        title: "Rocket Shapes",
        description: "Build a rocket from simple shapes",
        difficulty: 2,
        status: .published,
        sortOrder: 1,
        publishedAt: Date()
    )

    ClassroomLessonBookButton(
        lesson: lesson,
        pathTitle: "Space Missions",
        bookColor: NovaPalette.classroomPurple,
        isCompleted: true,
        isNewOverride: true
    ) { _ in }
    .padding(Spacing.lg)
    .background(NovaPalette.classroomPaper)
}
