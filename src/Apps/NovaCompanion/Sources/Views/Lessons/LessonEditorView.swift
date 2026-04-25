import SwiftUI
import NovaCore

/// Editor for lesson metadata and card management.
public struct LessonEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State var lesson: Lesson
    let onSave: (Lesson) -> Void


    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Lesson Metadata
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Lesson Details")
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)

                            VStack(spacing: 12) {
                                textField(label: "Title", text: $lesson.title)
                                // S12-12: lesson.description is now Optional<String>
                                // (Prisma column is nullable). Bridge through an
                                // adapter Binding so the existing String-typed
                                // textField helper keeps working — empty strings
                                // round-trip back to nil so the column reads as
                                // null on save instead of an empty-string row.
                                textField(label: "Description", text: Binding(
                                    get: { lesson.description ?? "" },
                                    set: { lesson.description = $0.isEmpty ? nil : $0 }
                                ), isMultiline: true)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Difficulty")
                                        .font(CompanionPalette.captionFont())
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)

                                    Picker("Difficulty", selection: $lesson.difficulty) {
                                        Text("Easy (1)").tag(1)
                                        Text("Medium (2)").tag(2)
                                        Text("Hard (3)").tag(3)
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                            .padding(12)
                            .background(CompanionPalette.companionCard)
                            .border(CompanionPalette.companionBorder, width: 1)
                            .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)

                        // Status Badge
                        HStack {
                            Image(systemName: statusIcon(lesson.status))
                                .font(.headline)
                                .foregroundStyle(statusColor(lesson.status))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(statusText(lesson.status))
                                    .font(CompanionPalette.bodyFont())
                                    .fontWeight(.semibold)

                                Text(statusDescription(lesson.status))
                                    .font(CompanionPalette.captionFont())
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { lesson.status == .published },
                                set: { lesson.status = $0 ? .published : .draft; lesson.publishedAt = $0 ? Date() : nil }
                            ))
                        }
                        .padding(12)
                        .background(CompanionPalette.companionCard)
                        .border(CompanionPalette.companionBorder, width: 1)
                        .cornerRadius(8)
                        .padding(.horizontal, 16)

                        // Cards Section with Editor Link
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Cards")
                                    .font(CompanionPalette.bodyFont())
                                    .fontWeight(.semibold)

                                Spacer()

                                Text("\(lesson.cards?.count ?? 0)")
                                    .font(CompanionPalette.captionFont())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(4)
                            }

                            // Open Card Editor Button
                            NavigationLink(destination: AdaptiveCardEditorView(lesson: lesson, onSave: onSave)) {
                                HStack {
                                    Image(systemName: "square.and.pencil")
                                    Text("Manage Cards")

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(CompanionPalette.novaBlue.opacity(0.1))
                                .foregroundStyle(CompanionPalette.novaBlue)
                                .cornerRadius(8)
                            }

                            // Preview Lesson Button
                            NavigationLink(destination: LessonPreviewView(lesson: lesson)) {
                                HStack {
                                    Image(systemName: "eye.fill")
                                    Text("Preview Lesson")

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(CompanionPalette.novaGreen.opacity(0.1))
                                .foregroundStyle(CompanionPalette.novaGreen)
                                .cornerRadius(8)
                            }

                            // Publish Button
                            NavigationLink(destination: PublishFlowView(lesson: lesson)) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Publish Lesson")

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .background(CompanionPalette.novaOrange.opacity(0.1))
                                .foregroundStyle(CompanionPalette.novaOrange)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 16)

                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.vertical, 16)
                }

                // Save/Cancel Footer
                VStack(spacing: 0) {
                    Divider()

                    HStack(spacing: 12) {
                        Button(role: .cancel, action: { dismiss() }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(CompanionPalette.companionBorder))
                        }

                        Button(action: {
                            onSave(lesson)
                            dismiss()
                        }) {
                            Text("Save Lesson")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(CompanionPalette.novaBlue)
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Edit Lesson")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func textField(label: String, text: Binding<String>, isMultiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(CompanionPalette.captionFont())
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if isMultiline {
                TextEditor(text: text)
                    .frame(minHeight: 60)
                    .font(CompanionPalette.bodyFont())
                    .padding(8)
                    .background(Color.white)
                    .border(CompanionPalette.companionBorder, width: 1)
                    .cornerRadius(6)
            } else {
                TextField(label, text: text)
                    .font(CompanionPalette.bodyFont())
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color.white)
                    .border(CompanionPalette.companionBorder, width: 1)
                    .cornerRadius(6)
            }
        }
    }

    private func statusIcon(_ status: Lesson.LessonStatus) -> String {
        switch status {
        case .draft:
            return "square.and.pencil"
        case .published:
            return "checkmark.circle.fill"
        case .review:
            return "hourglass"
        case .generating:
            return "waveform"
        }
    }

    private func statusColor(_ status: Lesson.LessonStatus) -> Color {
        switch status {
        case .draft:
            return CompanionPalette.statusDraft
        case .published:
            return CompanionPalette.statusPublished
        case .review:
            return CompanionPalette.statusDraft
        case .generating:
            return CompanionPalette.novaOrange
        }
    }

    private func statusText(_ status: Lesson.LessonStatus) -> String {
        switch status {
        case .draft:
            return "Draft"
        case .published:
            return "Published"
        case .review:
            return "Under Review"
        case .generating:
            return "Generating"
        }
    }

    private func statusDescription(_ status: Lesson.LessonStatus) -> String {
        switch status {
        case .draft:
            return "Not visible to children"
        case .published:
            return "Visible to children"
        case .review:
            return "Being analyzed for quality"
        case .generating:
            return "Being created by AI"
        }
    }
}

#Preview {
    LessonEditorView(
        lesson: Lesson(
            userId: UUID(),
            title: "Sample Lesson",
            description: "A sample lesson",
            difficulty: 1,
            status: .draft,
            sortOrder: 1
        ),
        onSave: { _ in }
    )
}
