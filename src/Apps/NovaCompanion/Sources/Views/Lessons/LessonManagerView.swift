import SwiftUI
import NovaCore

/// Manager for viewing and editing lessons.
public struct LessonManagerView: View {
    @StateObject private var viewModel = LessonManagerViewModel()
    @State private var selectedLesson: Lesson?
    @State private var isEditingLesson = false
    @State private var isCreatingLesson = false

    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                if viewModel.groupedLessons.isEmpty && viewModel.searchText.isEmpty && viewModel.statusFilter == nil {
                    EmptyStateView(
                        icon: "book",
                        title: "No Lessons Yet",
                        message: "Create your first lesson to start teaching your children with AI",
                        actionTitle: "Create Lesson",
                        action: { isCreatingLesson = true }
                    )
                } else if viewModel.groupedLessons.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Results",
                        message: "No lessons match your search or filter"
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Search and Filter
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    TextField("Search lessons...", text: $viewModel.searchText)
                                        .font(CompanionPalette.bodyFont())
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(CompanionPalette.companionCard)
                                .border(CompanionPalette.companionBorder, width: 1)
                                .cornerRadius(8)

                                HStack(spacing: 8) {
                                    FilterChip(
                                        label: "All",
                                        isSelected: viewModel.statusFilter == nil,
                                        action: { viewModel.statusFilter = nil }
                                    )

                                    FilterChip(
                                        label: "Draft",
                                        isSelected: viewModel.statusFilter == .draft,
                                        action: { viewModel.statusFilter = .draft }
                                    )

                                    FilterChip(
                                        label: "Published",
                                        isSelected: viewModel.statusFilter == .published,
                                        action: { viewModel.statusFilter = .published }
                                    )

                                    Spacer()
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            // Lessons Grouped by Path
                            ForEach(viewModel.groupedLessons, id: \.path?.id) { group in
                                VStack(alignment: .leading, spacing: 12) {
                                    if let path = group.path {
                                        HStack {
                                            Image(systemName: path.icon)
                                                .font(.headline)
                                                .foregroundStyle(CompanionPalette.pathColor(for: path.id.uuidString))

                                            Text(path.title)
                                                .font(CompanionPalette.bodyFont())
                                                .fontWeight(.semibold)

                                            Spacer()

                                            Text("\(group.lessons.count)")
                                                .font(CompanionPalette.captionFont())
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.gray.opacity(0.2))
                                                .cornerRadius(4)
                                        }
                                        .padding(.horizontal, 16)
                                    } else {
                                        Text("Uncategorized")
                                            .font(CompanionPalette.bodyFont())
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 16)
                                    }

                                    VStack(spacing: 8) {
                                        ForEach(group.lessons) { lesson in
                                            LessonListRow(
                                                lesson: lesson,
                                                onEdit: {
                                                    selectedLesson = lesson
                                                    isEditingLesson = true
                                                },
                                                onDelete: {
                                                    viewModel.deleteLesson(lesson)
                                                },
                                                onPublish: { shouldPublish in
                                                    if shouldPublish {
                                                        viewModel.publishLesson(lesson)
                                                    } else {
                                                        viewModel.unpublishLesson(lesson)
                                                    }
                                                }
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }

                            Spacer()
                                .frame(height: 20)
                        }
                        .padding(.vertical, 16)
                    }
                }

                // Floating Action Button
                VStack {
                    Spacer()

                    HStack {
                        Spacer()

                        Button(action: { isCreatingLesson = true }) {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                                .frame(width: 56, height: 56)
                                .background(CompanionPalette.novaBlue)
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding(24)
                    }
                }
            }
            .navigationTitle("Lessons")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isCreatingLesson) {
                LessonEditorView(
                    lesson: Lesson(
                        userId: UUID(),
                        title: "New Lesson",
                        description: "",
                        difficulty: 1,
                        status: .draft,
                        sortOrder: viewModel.allLessons.count + 1
                    ),
                    onSave: { lesson in
                        viewModel.allLessons.append(lesson)
                    }
                )
            }
            .sheet(isPresented: $isEditingLesson, item: $selectedLesson) { lesson in
                LessonEditorView(
                    lesson: lesson,
                    onSave: { updated in
                        if let index = viewModel.allLessons.firstIndex(where: { $0.id == lesson.id }) {
                            viewModel.allLessons[index] = updated
                        }
                    }
                )
            }
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(CompanionPalette.captionFont())
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? CompanionPalette.novaBlue : Color.gray.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

#Preview {
    LessonManagerView()
}
