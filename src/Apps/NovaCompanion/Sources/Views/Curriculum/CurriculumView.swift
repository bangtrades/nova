import SwiftUI
import NovaCore

/// Learning path management view showing all curriculum paths.
public struct CurriculumView: View {
    @StateObject private var viewModel = CurriculumViewModel()
    @State private var showCreatePath = false
    @State private var searchText = ""
    @State private var selectedStageFilter: String? = nil

    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search and Filter Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.subheadline.weight(.semibold))

                        TextField("Search paths...", text: $searchText)
                            .font(CompanionPalette.bodyFont())

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(CompanionPalette.companionCard)
                    .border(CompanionPalette.companionBorder, width: 1)
                    .cornerRadius(8)
                    .padding(16)

                    // Content
                    if viewModel.paths.isEmpty {
                        VStack(spacing: 24) {
                            Spacer()

                            EmptyStateView(
                                icon: "book.fill",
                                title: "No Learning Paths",
                                message: "Create your first learning path to organize lessons"
                            )

                            Button(action: { showCreatePath = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Create First Path")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(CompanionPalette.novaBlue)
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                            }
                            .padding(.horizontal, 16)

                            Spacer()
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                // Group by stage
                                let stageEnums: [ChildProfile.Stage] = [.explorer, .thinker, .maker, .creator]
                                let groupedPaths = Dictionary(grouping: filteredPaths) { $0.stage }

                                ForEach(stageEnums, id: \.self) { stage in
                                    if let stagePaths = groupedPaths[stage], !stagePaths.isEmpty {
                                        stageSection(stage: stage, paths: stagePaths)
                                    }
                                }
                            }
                            .padding(.vertical, 16)
                        }
                    }
                }

                // Create button
                VStack {
                    Spacer()

                    HStack {
                        Spacer()

                        Button(action: { showCreatePath = true }) {
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
            .navigationTitle("Curriculum")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCreatePath) {
                CreatePathView(isPresented: $showCreatePath, viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.loadPaths()
        }
    }

    // MARK: - Computed Properties

    private var filteredPaths: [LearningPath] {
        if searchText.isEmpty {
            return viewModel.paths
        }
        return viewModel.paths.filter { path in
            path.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Views

    @ViewBuilder
    private func stageSection(stage: ChildProfile.Stage, paths: [LearningPath]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(stage.displayName)
                    .font(CompanionPalette.bodyFont())
                    .fontWeight(.semibold)

                Circle()
                    .fill(CompanionPalette.pathColor(for: stage.displayName))
                    .frame(width: 8, height: 8)

                Spacer()
            }
            .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(paths.enumerated()), id: \.element.id) { index, path in
                    pathRow(path)

                    if index < paths.count - 1 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
            .background(CompanionPalette.companionCard)
            .border(CompanionPalette.companionBorder, width: 1)
            .cornerRadius(8)
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func pathRow(_ path: LearningPath) -> some View {
        NavigationLink(destination: PathEditorView(path: path, viewModel: viewModel)) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(path.title)
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    HStack(spacing: 12) {
                        Label(
                            "\(path.lessonCount) lessons",
                            systemImage: "book.fill"
                        )
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)

                        Text("\(path.completionPercentage)% complete")
                            .font(CompanionPalette.captionFont())
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(path.stageColor)
                            .frame(width: 6, height: 6)

                        Text(path.stage.displayName)
                            .font(CompanionPalette.captionFont())
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(CompanionPalette.companionBorder)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(path.stageColor)
                                .frame(
                                    width: geometry.size.width * CGFloat(path.completionPercentage) / 100
                                )
                        }
                    }
                    .frame(height: 4)
                }
                .frame(width: 60)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deletePath(id: path.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Create Path Sheet

struct CreatePathView: View {
    @Binding var isPresented: Bool
    var viewModel: CurriculumViewModel
    @State private var pathName = ""
    @State private var selectedStage = ChildProfile.Stage.explorer

    var body: some View {
        NavigationStack {
            Form {
                Section("Path Details") {
                    TextField("Path Name", text: $pathName)

                    Picker("Learning Stage", selection: $selectedStage) {
                        ForEach(ChildProfile.Stage.allCases, id: \.self) { stage in
                            Text(stage.displayName).tag(stage)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Create Path")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        viewModel.createPath(name: pathName, stage: selectedStage.displayName)
                        isPresented = false
                    }
                    .disabled(pathName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    CurriculumView()
}
