import SwiftUI
import NovaCore

/// Lessons tab showing all available lessons in a masonry grid.
///
/// Allows filtering by learning path and displays completion status.
public struct LessonsView: View {
    @StateObject private var viewModel = LessonsViewModel()
    @State private var selectedLesson: Lesson?
    @State private var showFlipbook = false

    public var body: some View {
        NavigationStack {
            ZStack {
                NovaPalette.novaBackground
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Learning paths filter
                        if !viewModel.learningPaths.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Filter by Path")
                                    .font(NovaPalette.headingFont())
                                    .foregroundStyle(.primary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        // All lessons button
                                        PathFilterButton(
                                            title: "All",
                                            isSelected: viewModel.selectedPath == nil
                                        ) {
                                            viewModel.selectPath(nil)
                                        }

                                        // Path filter buttons
                                        ForEach(viewModel.learningPaths) { path in
                                            PathFilterButton(
                                                title: path.title,
                                                isSelected: viewModel.selectedPath?.id == path.id
                                            ) {
                                                viewModel.selectPath(path)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 4)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        }

                        // Masonry grid
                        if viewModel.filteredLessons.isEmpty {
                            EmptyStateView(
                                title: "No lessons yet!",
                                subtitle: "Ask your parent to add some!",
                                icon: "sparkles"
                            )
                            .frame(minHeight: 400)
                        } else {
                            MasonryGrid(items: viewModel.filteredLessons, columns: 2, spacing: 12) { lesson in
                                NavigationLink(destination: {
                                    FlipbookView(lesson: lesson)
                                }) {
                                    LessonTileView(
                                        lesson: lesson,
                                        isComplete: viewModel.isLessonComplete(lesson)
                                    ) {
                                        selectedLesson = lesson
                                        showFlipbook = true
                                    }
                                }
                            }
                            .padding(20)
                        }
                    }
                }
            }
            .navigationTitle("Lessons")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Filter button for learning paths.
private struct PathFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NovaPalette.smallHeadingFont())
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(isSelected ? NovaPalette.novaBlue : NovaPalette.ink.opacity(0.1))
                .cornerRadius(8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

#Preview {
    LessonsView()
}
