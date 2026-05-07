import SwiftUI
import NovaCore

/// Reusable v2 classroom bookshelf view for browsing lessons by learning path.
public struct ClassroomLessonLibraryView: View {
    private let paths: [LearningPath]
    private let lessons: [Lesson]
    private let completedLessonIds: Set<UUID>
    private let newLessonIds: Set<UUID>
    private let onSelectLesson: (Lesson) -> Void

    public init(
        paths: [LearningPath],
        lessons: [Lesson],
        completedLessonIds: Set<UUID> = [],
        newLessonIds: Set<UUID> = [],
        onSelectLesson: @escaping (Lesson) -> Void
    ) {
        self.paths = paths
        self.lessons = lessons
        self.completedLessonIds = completedLessonIds
        self.newLessonIds = newLessonIds
        self.onSelectLesson = onSelectLesson
    }

    public var body: some View {
        ZStack {
            // Soft classroom-paper-to-wood vertical wash so the
            // background reads as the wall behind a bookshelf rather
            // than a flat app surface. Stays inside the classroom
            // palette tokens; no neon, no hard color edges.
            LinearGradient(
                colors: [
                    NovaPalette.classroomPaper,
                    NovaPalette.classroomPaper.opacity(0.92),
                    NovaPalette.classroomWood.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header

                    if shelfSections.isEmpty {
                        emptyShelf
                    } else {
                        ForEach(shelfSections) { section in
                            ClassroomLessonShelfSection(
                                section: section,
                                completedLessonIds: completedLessonIds,
                                newLessonIds: newLessonIds,
                                onSelectLesson: onSelectLesson
                            )
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.lg)
            }
        }
    }

    /// Library header — a small book-stack sticker beside the
    /// "Bookshelf" title, with the friendly subtitle below. The
    /// sticker anchors the page so it reads as a labeled bookshelf
    /// section instead of a generic title row.
    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(NovaPalette.classroomSun)
                    .overlay(
                        Circle()
                            .stroke(NovaPalette.classroomInk, lineWidth: 2)
                    )
                Image(systemName: "books.vertical.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(NovaPalette.classroomInk)
                    .accessibilityHidden(true)
            }
            .frame(width: 48, height: 48)
            .shadow(color: NovaPalette.classroomInk.opacity(0.18), radius: 3, x: 0, y: 2)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Bookshelf")
                    .font(NovaPalette.titleFont())
                    .foregroundStyle(NovaPalette.classroomInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text("Pick a lesson book.")
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(NovaPalette.classroomInk.opacity(0.72))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyShelf: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            emptyShelfPrompt
                .frame(maxWidth: 520, alignment: .leading)

            emptyShelfScene
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("The bookshelf is empty. The shelf is waiting. New lesson books will appear after a grown-up adds them.")
    }

    private var shelfSections: [LessonShelfSection] {
        let pathsById = Dictionary(uniqueKeysWithValues: paths.map { ($0.id, $0) })
        let lessonsByPath = Dictionary(grouping: lessons) { lesson in
            lesson.pathId
        }

        var sections = paths
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.title < rhs.title
                }
                return lhs.sortOrder < rhs.sortOrder
            }
            .compactMap { path -> LessonShelfSection? in
                guard let pathLessons = lessonsByPath[path.id], pathLessons.isEmpty == false else {
                    return nil
                }

                return LessonShelfSection(
                    id: path.id.uuidString,
                    title: path.title,
                    subtitle: "\(pathLessons.count) \(pathLessons.count == 1 ? "book" : "books")",
                    lessons: sorted(pathLessons),
                    pathTitle: path.title
                )
            }

        let knownPathIds = Set(pathsById.keys)
        let extraLessons = lessons.filter { lesson in
            guard let pathId = lesson.pathId else { return true }
            return knownPathIds.contains(pathId) == false
        }

        if extraLessons.isEmpty == false {
            sections.append(
                LessonShelfSection(
                    id: "other-lessons",
                    title: "Extra Books",
                    subtitle: "\(extraLessons.count) \(extraLessons.count == 1 ? "book" : "books")",
                    lessons: sorted(extraLessons),
                    pathTitle: nil
                )
            )
        }

        return sections
    }

    private func sorted(_ lessons: [Lesson]) -> [Lesson] {
        lessons.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.title < rhs.title
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private var emptyShelfPrompt: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("The shelf is waiting.")
                .font(NovaPalette.headingFont())
                .foregroundStyle(NovaPalette.classroomInk)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Text("New lesson books will appear after a grown-up adds them.")
                .font(NovaPalette.bodyFont())
                .foregroundStyle(NovaPalette.classroomInk.opacity(0.74))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.lg)
        .background(
            SpeechNoteShape()
                .fill(NovaPalette.classroomPaper)
        )
        .overlay(
            SpeechNoteShape()
                .stroke(NovaPalette.classroomInk, lineWidth: 2)
        )
        .shadow(color: NovaPalette.classroomInk.opacity(0.10), radius: 3, x: 0, y: 2)
    }

    private var emptyShelfScene: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(spacing: Spacing.sm) {
                emptyShelfPlank(widthRatio: 0.92)
                emptyShelfPlank(widthRatio: 1.0)
            }
            .padding(.top, Spacing.xl)

            HStack(alignment: .bottom, spacing: Spacing.lg) {
                emptyBookend(color: NovaPalette.classroomPurple.opacity(0.78))
                emptyBookend(color: NovaPalette.classroomSky.opacity(0.70))
                Spacer(minLength: Spacing.md)
                emptyShelfNote
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .bottomLeading)
    }

    private func emptyShelfPlank(widthRatio: CGFloat) -> some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(NovaPalette.classroomWood)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(NovaPalette.classroomInk, lineWidth: 2)
                )
                .frame(width: geometry.size.width * widthRatio, height: 28)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 28)
        .accessibilityHidden(true)
    }

    private func emptyBookend(color: Color) -> some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(NovaPalette.classroomInk, lineWidth: 2)
                )
                .frame(width: 30, height: 72)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(NovaPalette.classroomWood)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(NovaPalette.classroomInk, lineWidth: 2)
                )
                .frame(width: 54, height: 16)
        }
        .accessibilityHidden(true)
    }

    private var emptyShelfNote: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(NovaPalette.classroomPaper)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(NovaPalette.classroomInk, lineWidth: 2)
                )
                .frame(width: 92, height: 72)

            Circle()
                .fill(NovaPalette.classroomSun)
                .overlay(
                    Circle()
                        .stroke(NovaPalette.classroomInk, lineWidth: 1.5)
                )
                .frame(width: 18, height: 18)
                .offset(x: 5, y: -5)

            Image(systemName: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundStyle(NovaPalette.classroomPurple)
                .frame(width: 92, height: 72)
                .accessibilityHidden(true)
        }
        .rotationEffect(.degrees(-3))
        .accessibilityHidden(true)
    }
}

private struct SpeechNoteShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cornerRadius: CGFloat = min(18, rect.height * 0.28)
        let tailWidth: CGFloat = min(22, rect.width * 0.08)
        let tailHeight: CGFloat = min(18, rect.height * 0.20)
        var path = Path()

        path.addRoundedRect(
            in: CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: rect.height - tailHeight
            ),
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )

        path.move(to: CGPoint(x: rect.minX + cornerRadius + tailWidth, y: rect.maxY - tailHeight))
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius + tailWidth * 0.45, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius + tailWidth * 1.8, y: rect.maxY - tailHeight))
        path.closeSubpath()

        return path
    }
}

private struct LessonShelfSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let lessons: [Lesson]
    let pathTitle: String?
}

private struct ClassroomLessonShelfSection: View {
    let section: LessonShelfSection
    let completedLessonIds: Set<UUID>
    let newLessonIds: Set<UUID>
    let onSelectLesson: (Lesson) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .center, spacing: Spacing.sm) {
                Text(section.title)
                    .font(NovaPalette.headingFont())
                    .foregroundStyle(NovaPalette.classroomInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // Section count rendered as a small paper sticker
                // pill so each shelf row reads as a labeled section
                // ("Space Missions · 5 books") rather than two
                // floating text fragments.
                Text(section.subtitle)
                    .font(NovaPalette.captionFont().weight(.semibold))
                    .foregroundStyle(NovaPalette.classroomInk)
                    .lineLimit(1)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(NovaPalette.classroomSun.opacity(0.55))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(NovaPalette.classroomInk.opacity(0.50), lineWidth: 1)
                    )

                Spacer(minLength: Spacing.sm)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .bottom, spacing: Spacing.md) {
                    ForEach(Array(section.lessons.enumerated()), id: \.element.id) { index, lesson in
                        ClassroomLessonBookButton(
                            lesson: lesson,
                            pathTitle: section.pathTitle,
                            bookColor: bookColor(for: index),
                            isCompleted: completedLessonIds.contains(lesson.id),
                            isNewOverride: newLessonIds.isEmpty ? nil : newLessonIds.contains(lesson.id),
                            onSelectLesson: onSelectLesson
                        )
                    }
                }
                .padding(.horizontal, Spacing.xs)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.md)
            }

            shelfBoard
                .frame(height: 24)
                .padding(.top, -Spacing.lg)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(NovaPalette.classroomPaper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(NovaPalette.classroomInk.opacity(0.22), lineWidth: 2)
        )
        .accessibilityElement(children: .contain)
    }

    private func bookColor(for index: Int) -> Color {
        let colors = [
            NovaPalette.classroomSchoolRed,
            NovaPalette.classroomSky,
            NovaPalette.classroomPurple,
            NovaPalette.classroomLeaf,
            NovaPalette.classroomChalkboard,
        ]
        return colors[index % colors.count]
    }

    private var shelfBoard: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(NovaPalette.classroomWood)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(NovaPalette.classroomInk, lineWidth: 2)
            )
            .shadow(color: NovaPalette.classroomInk.opacity(0.16), radius: 3, x: 0, y: 2)
    }
}

#Preview {
    let userId = UUID()
    let spacePathId = UUID()
    let robotPathId = UUID()
    let paths = [
        LearningPath(
            id: spacePathId,
            userId: userId,
            title: "Space Missions",
            description: "Explore rockets and planets",
            color: nil,
            icon: "sparkles",
            sortOrder: 1,
            stage: .explorer,
            isPremium: false
        ),
        LearningPath(
            id: robotPathId,
            userId: userId,
            title: "Robot Lab",
            description: "Meet helpful machines",
            color: nil,
            icon: "cpu",
            sortOrder: 2,
            stage: .thinker,
            isPremium: false
        ),
    ]

    let lessons = [
        Lesson(
            pathId: spacePathId,
            userId: userId,
            title: "Rocket Shapes",
            description: "Build a rocket from simple shapes",
            difficulty: 1,
            status: .published,
            sortOrder: 1,
            publishedAt: Date()
        ),
        Lesson(
            pathId: spacePathId,
            userId: userId,
            title: "Moon Walk",
            description: "Learn why astronauts bounce",
            difficulty: 2,
            status: .published,
            sortOrder: 2,
            publishedAt: Date(timeIntervalSinceNow: -10 * 24 * 60 * 60)
        ),
        Lesson(
            pathId: robotPathId,
            userId: userId,
            title: "Robot Helpers",
            description: "Find robots around us",
            difficulty: 2,
            status: .published,
            sortOrder: 1,
            publishedAt: Date()
        ),
    ]

    ClassroomLessonLibraryView(
        paths: paths,
        lessons: lessons,
        completedLessonIds: [lessons[1].id],
        newLessonIds: [lessons[0].id]
    ) { _ in }
}
