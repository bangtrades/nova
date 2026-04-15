import SwiftUI
import NovaCore

/// UIActivityViewController wrapper for sharing lessons and content.
public struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]
    @Environment(\.dismiss) var dismiss

    public init(items: [Any]) {
        self.items = items
    }

    public func makeUIViewController(context: UIViewControllerRepresentableContext<ShareSheetView>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)

        controller.completionWithItemsHandler = { _, _, _, _ in
            dismiss()
        }

        return controller
    }

    public func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: UIViewControllerRepresentableContext<ShareSheetView>
    ) {}
}

// MARK: - Lesson Share Builder

/// Builds shareable content from a lesson.
public struct LessonShareBuilder {
    let lesson: Lesson

    public init(lesson: Lesson) {
        self.lesson = lesson
    }

    /// Generate formatted text summary for sharing.
    public var textSummary: String {
        var summary = "Check out this Nova lesson: '\(lesson.title)'\n\n"

        summary += "📚 Content:\n"
        summary += "• Cards: \(lesson.cards?.count ?? 0)\n"
        summary += "• Status: \(lesson.status.rawValue)\n"

        if !lesson.description.isEmpty {
            summary += "\n📝 Description:\n\(lesson.description)\n"
        }

        summary += "\n✨ Created with Nova Companion\n"
        summary += "Learn AI at your own pace with interactive lessons"

        return summary
    }

    /// Generate deep link for sharing.
    public var deepLink: String {
        "nova://lesson/\(lesson.id)"
    }

    /// Generate full formatted message with link.
    public var formattedShareMessage: String {
        return textSummary + "\nOpen: \(deepLink)"
    }

    /// Get shareable items for UIActivityViewController.
    public var shareItems: [Any] {
        return [formattedShareMessage]
    }
}

// MARK: - Export View

/// Export options for a lesson (share, copy, etc.)
public struct ExportLessonView: View {
    @Environment(\.dismiss) var dismiss
    let lesson: Lesson
    @State private var showingShareSheet = false
    @State private var showingCopyConfirmation = false
    @State private var copiedMessage = ""
    @State private var confirmationTask: Task<Void, Never>?

    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Export '\(lesson.title)'")
                            .font(CompanionPalette.titleFont())
                            .fontWeight(.bold)

                        Text("Share this lesson with others")
                            .font(CompanionPalette.secondaryBodyFont())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)

                    ScrollView {
                        VStack(spacing: 12) {
                            exportOptionButton(
                                icon: "square.and.arrow.up",
                                title: "Share as Text",
                                subtitle: "Message, email, notes, etc.",
                                color: CompanionPalette.novaBlue
                            ) {
                                showingShareSheet = true
                            }

                            exportOptionButton(
                                icon: "link",
                                title: "Copy Deep Link",
                                subtitle: "nova://lesson/\(lesson.id)",
                                color: CompanionPalette.novaOrange
                            ) {
                                copyDeepLink()
                            }

                            exportOptionButton(
                                icon: "doc.on.clipboard",
                                title: "Copy to Clipboard",
                                subtitle: "Full lesson summary",
                                color: CompanionPalette.novaGreen
                            ) {
                                copyToClipboard()
                            }
                        }
                        .padding(16)
                    }

                    Spacer()

                    Button(action: { dismiss() }) {
                        Text("Done")
                            .font(CompanionPalette.bodyFont())
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(CompanionPalette.companionBorder)
                            .foregroundStyle(.primary)
                            .cornerRadius(8)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShareSheet) {
                let builder = LessonShareBuilder(lesson: lesson)
                ShareSheetView(items: builder.shareItems)
            }
            .onDisappear {
                confirmationTask?.cancel()
            }
        }
    }

    @ViewBuilder
    private func exportOptionButton(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 40, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(CompanionPalette.companionCard)
            .border(CompanionPalette.companionBorder, width: 1)
            .cornerRadius(8)
        }
    }

    private func copyDeepLink() {
        let builder = LessonShareBuilder(lesson: lesson)
        UIPasteboard.general.string = builder.deepLink
        showCopyConfirmation("Deep link copied!")
    }

    private func copyToClipboard() {
        let builder = LessonShareBuilder(lesson: lesson)
        UIPasteboard.general.string = builder.formattedShareMessage
        showCopyConfirmation("Lesson summary copied!")
    }

    private func showCopyConfirmation(_ message: String) {
        copiedMessage = message
        showingCopyConfirmation = true

        confirmationTask?.cancel()
        confirmationTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            showingCopyConfirmation = false
        }
    }
}

// MARK: - Preview

#Preview {
    let mockLesson = Lesson(
        id: UUID(),
        userId: UUID(),
        title: "Introduction to AI",
        description: "Learn the basics of artificial intelligence",
        difficulty: 1,
        status: .published,
        sortOrder: 1
    )

    ExportLessonView(lesson: mockLesson)
}
