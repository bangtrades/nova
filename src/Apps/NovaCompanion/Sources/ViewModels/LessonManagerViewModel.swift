import Foundation
import NovaCore

/// ViewModel for lesson management with mock data.
public class LessonManagerViewModel: ObservableObject {
    @Published var allLessons: [Lesson] = []
    @Published var learningPaths: [LearningPath] = []
    @Published var searchText: String = ""
    @Published var statusFilter: Lesson.LessonStatus?

    public init() {
        loadMockData()
    }

    private func loadMockData() {
        // Mock Learning Paths
        learningPaths = [
            LearningPath(
                userId: UUID(),
                title: "AI Basics",
                description: "Introduction to artificial intelligence concepts",
                color: "4A90D9",
                icon: "brain",
                sortOrder: 1,
                stage: .explorer,
                isPremium: false
            ),
            LearningPath(
                userId: UUID(),
                title: "Machine Learning",
                description: "Understanding how machines learn from data",
                color: "FF8C42",
                icon: "gear",
                sortOrder: 2,
                stage: .thinker,
                isPremium: false
            ),
            LearningPath(
                userId: UUID(),
                title: "Creative AI",
                description: "Using AI for creative expression",
                color: "9B59B6",
                icon: "sparkles",
                sortOrder: 3,
                stage: .maker,
                isPremium: true
            ),
        ]

        // Mock Lessons
        let pathId1 = learningPaths[0].id
        let pathId2 = learningPaths[1].id
        let pathId3 = learningPaths[2].id

        allLessons = [
            Lesson(
                pathId: pathId1,
                userId: UUID(),
                title: "What is AI?",
                description: "An introduction to artificial intelligence and how it works",
                difficulty: 1,
                status: .published,
                sortOrder: 1,
                publishedAt: Date().addingTimeInterval(-86400 * 7)
            ),
            Lesson(
                pathId: pathId1,
                userId: UUID(),
                title: "AI in Daily Life",
                description: "Discovering AI applications in everyday situations",
                difficulty: 1,
                status: .published,
                sortOrder: 2,
                publishedAt: Date().addingTimeInterval(-86400 * 5)
            ),
            Lesson(
                pathId: pathId2,
                userId: UUID(),
                title: "Data and Learning",
                description: "How machines learn from data patterns",
                difficulty: 2,
                status: .published,
                sortOrder: 1,
                publishedAt: Date().addingTimeInterval(-86400 * 3)
            ),
            Lesson(
                pathId: pathId2,
                userId: UUID(),
                title: "Training Neural Networks",
                description: "Basics of neural network training (DRAFT)",
                difficulty: 2,
                status: .draft,
                sortOrder: 2
            ),
            Lesson(
                pathId: pathId3,
                userId: UUID(),
                title: "AI Art Generation",
                description: "Using generative models for creative work",
                difficulty: 3,
                status: .draft,
                sortOrder: 1
            ),
            Lesson(
                pathId: nil,
                userId: UUID(),
                title: "Ethics in AI",
                description: "Understanding AI ethics and responsible AI (ARCHIVED)",
                difficulty: 2,
                status: .review,
                sortOrder: 1
            ),
        ]
    }

    var filteredLessons: [Lesson] {
        var result = allLessons

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { lesson in
                lesson.title.localizedCaseInsensitiveContains(searchText) ||
                (lesson.description ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        // Filter by status
        if let statusFilter = statusFilter {
            result = result.filter { $0.status == statusFilter }
        }

        return result.sorted { $0.createdAt > $1.createdAt }
    }

    var groupedLessons: [(path: LearningPath?, lessons: [Lesson])] {
        var grouped: [(path: LearningPath?, lessons: [Lesson])] = []

        // Group by learning path
        for path in learningPaths {
            let pathLessons = filteredLessons.filter { $0.pathId == path.id }
            if !pathLessons.isEmpty {
                grouped.append((path: path, lessons: pathLessons))
            }
        }

        // Add orphaned lessons
        let orphaned = filteredLessons.filter { $0.pathId == nil }
        if !orphaned.isEmpty {
            grouped.append((path: nil, lessons: orphaned))
        }

        return grouped
    }

    func publishLesson(_ lesson: Lesson) {
        if let index = allLessons.firstIndex(where: { $0.id == lesson.id }) {
            allLessons[index].status = .published
            allLessons[index].publishedAt = Date()
        }
    }

    func unpublishLesson(_ lesson: Lesson) {
        if let index = allLessons.firstIndex(where: { $0.id == lesson.id }) {
            allLessons[index].status = .draft
            allLessons[index].publishedAt = nil
        }
    }

    func deleteLesson(_ lesson: Lesson) {
        allLessons.removeAll { $0.id == lesson.id }
    }
}
