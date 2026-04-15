import SwiftUI
import NovaCore

/// Editor for learning path details, lessons, and ordering.
public struct PathEditorView: View {
    @State var path: LearningPath
    var viewModel: CurriculumViewModel
    @Environment(\.dismiss) var dismiss

    @State private var pathName: String = ""
    @State private var selectedStage: ChildProfile.Stage = .explorer
    @State private var lessons: [PathLesson] = []
    @State private var showLessonPicker = false
    @State private var isDirty = false

    public var body: some View {
        NavigationStack {
            Form {
                Section("Path Details") {
                    TextField("Path Name", text: $pathName)
                        .onChange(of: pathName) { _, _ in isDirty = true }

                    Picker("Learning Stage", selection: $selectedStage) {
                        ForEach(ChildProfile.Stage.allCases, id: \.self) { stage in
                            Text(stage.displayName).tag(stage)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedStage) { _, _ in isDirty = true }
                }

                Section("Lessons") {
                    if lessons.isEmpty {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundStyle(.secondary)

                            Text("No lessons added yet")
                                .foregroundStyle(.secondary)

                            Spacer()

                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                        }
                        .onTapGesture {
                            showLessonPicker = true
                        }
                    } else {
                        ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                            NavigationLink(destination: lessonDetail(lesson)) {
                                lessonRow(lesson)
                            }
                        }
                        .onMove(perform: moveLessons)
                        .onDelete(perform: deleteLessons)
                    }

                    Button(action: { showLessonPicker = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(CompanionPalette.novaBlue)

                            Text("Add Lesson")
                                .foregroundStyle(CompanionPalette.novaBlue)
                        }
                    }
                }

                Section("Statistics") {
                    HStack {
                        Text("Total Lessons")
                        Spacer()
                        Text("\(lessons.count)")
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("Estimated Duration")
                        Spacer()
                        Text(estimatedDuration())
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle("Edit Path")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        savePath()
                        dismiss()
                    }
                    .disabled(!isDirty)
                }
            }
            .sheet(isPresented: $showLessonPicker) {
                LessonPickerView(
                    isPresented: $showLessonPicker,
                    selectedLessons: $lessons
                )
            }
        }
        .onAppear {
            pathName = path.title
            selectedStage = path.stage
            loadMockLessons()
        }
    }

    // MARK: - Views

    @ViewBuilder
    private func lessonRow(_ lesson: PathLesson) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(CompanionPalette.bodyFont())
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    Label("\(lesson.cardCount) cards", systemImage: "square.grid.2x2")
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)

                    if lesson.isPublished {
                        Label("Published", systemImage: "checkmark.circle.fill")
                            .font(CompanionPalette.captionFont())
                            .foregroundStyle(CompanionPalette.statusPublished)
                    } else {
                        Label("Draft", systemImage: "pencil.circle.fill")
                            .font(CompanionPalette.captionFont())
                            .foregroundStyle(CompanionPalette.statusDraft)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func lessonDetail(_ lesson: PathLesson) -> some View {
        VStack {
            Text(lesson.title)
        }
    }

    // MARK: - Actions

    private func savePath() {
        // Update mutable properties
        // In production, call API to update path
        isDirty = false
    }

    private func moveLessons(from source: IndexSet, to destination: Int) {
        lessons.move(fromOffsets: source, toOffset: destination)
        isDirty = true
    }

    private func deleteLessons(offsets: IndexSet) {
        lessons.remove(atOffsets: offsets)
        isDirty = true
    }

    private func estimatedDuration() -> String {
        let totalMinutes = lessons.reduce(0) { $0 + $1.estimatedMinutes }
        return "\(totalMinutes) min"
    }

    private func loadMockLessons() {
        lessons = [
            PathLesson(
                id: UUID(),
                title: "Introduction to AI",
                cardCount: 8,
                estimatedMinutes: 15,
                isPublished: true
            ),
            PathLesson(
                id: UUID(),
                title: "Machine Learning Basics",
                cardCount: 12,
                estimatedMinutes: 20,
                isPublished: true
            ),
            PathLesson(
                id: UUID(),
                title: "Neural Networks",
                cardCount: 10,
                estimatedMinutes: 18,
                isPublished: false
            ),
        ]
    }
}

// MARK: - Lesson Picker Sheet

struct LessonPickerView: View {
    @Binding var isPresented: Bool
    @Binding var selectedLessons: [PathLesson]
    @State private var availableLessons: [PathLesson] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(availableLessons) { lesson in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.title)
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)

                            Text("\(lesson.cardCount) cards")
                                .font(CompanionPalette.captionFont())
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if selectedLessons.contains(where: { $0.id == lesson.id }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(CompanionPalette.novaGreen)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleLessonSelection(lesson)
                    }
                }
            }
            .navigationTitle("Select Lessons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            loadAvailableLessons()
        }
    }

    private func toggleLessonSelection(_ lesson: PathLesson) {
        if let index = selectedLessons.firstIndex(where: { $0.id == lesson.id }) {
            selectedLessons.remove(at: index)
        } else {
            selectedLessons.append(lesson)
        }
    }

    private func loadAvailableLessons() {
        availableLessons = [
            PathLesson(
                id: UUID(),
                title: "Introduction to AI",
                cardCount: 8,
                estimatedMinutes: 15,
                isPublished: true
            ),
            PathLesson(
                id: UUID(),
                title: "Machine Learning Basics",
                cardCount: 12,
                estimatedMinutes: 20,
                isPublished: true
            ),
            PathLesson(
                id: UUID(),
                title: "Neural Networks",
                cardCount: 10,
                estimatedMinutes: 18,
                isPublished: false
            ),
            PathLesson(
                id: UUID(),
                title: "Deep Learning Intro",
                cardCount: 14,
                estimatedMinutes: 22,
                isPublished: true
            ),
        ]
    }
}

// MARK: - Data Models

struct PathLesson: Identifiable {
    let id: UUID
    let title: String
    let cardCount: Int
    let estimatedMinutes: Int
    let isPublished: Bool
}

#Preview {
    PathEditorView(
        path: LearningPath(
            id: UUID(),
            userId: UUID(),
            title: "Test Path",
            description: "Test",
            color: "#3B82F6",
            icon: "book.fill",
            sortOrder: 0,
            stage: .explorer,
            isPremium: false,
            lessons: nil
        ),
        viewModel: CurriculumViewModel()
    )
}
