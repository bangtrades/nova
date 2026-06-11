import SwiftUI
import NovaCore

/// URL intake view for the content pipeline.
///
/// Allows parents to submit URLs for lesson generation. Shows the analysis
/// and generation progress with visual feedback.
public struct URLIntakeView: View {
    @StateObject private var viewModel: URLIntakeViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showPasteAlert = false
    @State private var pastedURL: String?

    /// Initialize the URL intake view.
    /// - Parameters:
    ///   - apiRouter: The API router for making requests.
    public init(apiRouter: APIRouting) {
        _viewModel = StateObject(wrappedValue: URLIntakeViewModel(apiRouter: apiRouter))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Create Lesson from URL")
                                .font(CompanionPalette.titleFont())
                                .fontWeight(.bold)

                            Text("Paste a URL and Nova will analyze it to create an AI lesson")
                                .font(CompanionPalette.secondaryBodyFont())
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // URL Input Section
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "link")
                                    .foregroundStyle(.secondary)

                                TextField("Paste URL here", text: $viewModel.urlString)
                                    .keyboardType(.URL)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)

                                if !viewModel.urlString.isEmpty {
                                    Button(action: { viewModel.urlString = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(12)
                            .background(CompanionPalette.companionCard)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(CompanionPalette.companionBorder, lineWidth: 1)
                            )

                            HStack {
                                Button(action: {
                                    // Attempt to get pasteboard
                                    if let pasted = UIPasteboard.general.string {
                                        viewModel.urlString = pasted
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "doc.on.clipboard")
                                        Text("Paste")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(10)
                                    .foregroundStyle(.white)
                                    .background(CompanionPalette.novaBlue)
                                    .cornerRadius(6)
                                }

                                Spacer()

                                Button(action: {
                                    Task {
                                        await viewModel.analyzeURL()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                        Text("Analyze")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(10)
                                    .foregroundStyle(.white)
                                    .background(CompanionPalette.novaOrange)
                                    .cornerRadius(6)
                                }
                                .disabled(viewModel.urlString.trimmingCharacters(in: .whitespaces).isEmpty ||
                                           viewModel.state == .scraping || viewModel.state == .analyzing)
                            }
                        }
                        .padding(16)
                        .background(CompanionPalette.companionCard)
                        .cornerRadius(12)

                        // Status Section
                        switch viewModel.state {
                        case .idle:
                            EmptyView()

                        case .scraping, .analyzing:
                            AnalysisProgressView(state: viewModel.state)

                        case .ready:
                            AnalysisResultsView(analysis: viewModel.analysis)

                        case .generating:
                            GenerationProgressView()

                        case .completed:
                            CompletionView(lessonId: viewModel.generatedLessonId ?? "", onDismiss: {
                                dismiss()
                            })

                        case .error:
                            ErrorView(message: viewModel.errorMessage ?? "An error occurred", onRetry: {
                                viewModel.reset()
                            })
                        }

                        // Generate Button
                        if viewModel.state == .ready && viewModel.analysis != nil {
                            Button(action: {
                                Task {
                                    await viewModel.generateLesson()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Generate Lesson")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .font(CompanionPalette.headingFont())
                                .foregroundStyle(.white)
                                .background(CompanionPalette.novaGreen)
                                .cornerRadius(8)
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer()
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sub Views

/// Shows analysis progress with animated spinner.
private struct AnalysisProgressView: View {
    let state: URLIntakeViewModel.IntakeState

    @State private var spinnerRotation = 0.0

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(CompanionPalette.novaBlue)
                .rotationEffect(.degrees(spinnerRotation))
                .onAppear {
                    withAnimation(
                        Animation.linear(duration: 2).repeatForever(autoreverses: false)
                    ) {
                        spinnerRotation = 360
                    }
                }

            VStack(spacing: 4) {
                Text("Nova is reading this...")
                    .font(CompanionPalette.headingFont())
                    .fontWeight(.semibold)

                Text(state == .scraping ? "Fetching content..." : "Analyzing...")
                    .font(CompanionPalette.secondaryBodyFont())
                    .foregroundStyle(.secondary)
            }

            ProgressView()
                .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(CompanionPalette.companionCard)
        .cornerRadius(12)
    }
}

/// Shows analysis results.
private struct AnalysisResultsView: View {
    let analysis: ContentAnalysis?

    var body: some View {
        guard let analysis = analysis else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(spacing: 16) {
                // Topic
                VStack(alignment: .leading, spacing: 8) {
                    Label("Topic", systemImage: "target")
                        .font(CompanionPalette.headingFont())
                        .fontWeight(.semibold)
                        .foregroundStyle(CompanionPalette.novaBlue)

                    Text(analysis.topic)
                        .font(CompanionPalette.bodyFont())
                }

                Divider()

                // Key Concepts
                VStack(alignment: .leading, spacing: 8) {
                    Label("Key Concepts", systemImage: "sparkles")
                        .font(CompanionPalette.headingFont())
                        .fontWeight(.semibold)
                        .foregroundStyle(CompanionPalette.novaOrange)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(analysis.keyConcepts, id: \.self) { concept in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(CompanionPalette.novaGreen)
                                    .font(.caption)

                                Text(concept)
                                    .font(CompanionPalette.secondaryBodyFont())
                            }
                        }
                    }
                }

                Divider()

                // Card Count
                HStack {
                    Label("Estimated Cards", systemImage: "square.grid.2x2")
                        .font(CompanionPalette.headingFont())
                        .fontWeight(.semibold)
                        .foregroundStyle(CompanionPalette.novaPurple)

                    Spacer()

                    Text("\(analysis.cardCount) cards")
                        .font(CompanionPalette.headingFont())
                        .fontWeight(.bold)
                        .foregroundStyle(CompanionPalette.novaPurple)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(CompanionPalette.companionCard)
            .cornerRadius(12)
        )
    }
}

/// Shows generation progress.
private struct GenerationProgressView: View {
    @State private var progress = 0.4

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wand.and.stars")
                .font(.largeTitle)
                .foregroundStyle(CompanionPalette.novaOrange)

            VStack(spacing: 4) {
                Text("Generating cards...")
                    .font(CompanionPalette.headingFont())
                    .fontWeight(.semibold)

                Text("Nova is creating personalized learning cards")
                    .font(CompanionPalette.secondaryBodyFont())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .onAppear {
                    withAnimation(
                        Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)
                    ) {
                        progress = 0.9
                    }
                }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(CompanionPalette.companionCard)
        .cornerRadius(12)
    }
}

/// Shows completion state.
private struct CompletionView: View {
    let lessonId: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(CompanionPalette.novaGreen)

            VStack(spacing: 4) {
                Text("Done! Lesson created")
                    .font(CompanionPalette.headingFont())
                    .fontWeight(.semibold)

                Text("Your new lesson is ready to edit and share with your child")
                    .font(CompanionPalette.secondaryBodyFont())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onDismiss) {
                HStack {
                    Image(systemName: "pencil.and.list.clipboard")
                    Text("Edit Lesson")
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .font(CompanionPalette.headingFont())
                .foregroundStyle(.white)
                .background(CompanionPalette.novaBlue)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(CompanionPalette.companionCard)
        .cornerRadius(12)
    }
}

/// Shows error state.
private struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.red)

            VStack(spacing: 4) {
                Text("Something went wrong")
                    .font(CompanionPalette.headingFont())
                    .fontWeight(.semibold)

                Text(message)
                    .font(CompanionPalette.secondaryBodyFont())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onRetry) {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Try Again")
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .font(CompanionPalette.headingFont())
                .foregroundStyle(.white)
                .background(Color.red)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(CompanionPalette.companionCard)
        .cornerRadius(12)
    }
}

// Build fix (Jun 11): the mock lived inside the #Preview closure, which
// must be a single View-building expression — a local type declaration
// plus a trailing expression doesn't satisfy the macro ("no exact
// matches in call to macro 'Preview'"). Hoisted to file scope.
private struct PreviewMockAPIRouter: APIRouting {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        throw APIError.networkError(NSError(domain: "", code: 0))
    }
}

#Preview {
    URLIntakeView(apiRouter: PreviewMockAPIRouter())
}
