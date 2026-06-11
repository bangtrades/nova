import SwiftUI
import NovaCore

/// Per-child profile editor with avatar, name, age, preferences, and data management.
public struct ChildProfileView: View {
    @State var childProfile: ChildProfile
    @Environment(\.dismiss) var dismiss
    @State private var selectedAvatar: String = "robot.fill"
    @State private var childName: String = ""
    @State private var childAge: Int = 4
    @State private var preferredLessonLength: String = "medium"
    @State private var autoNarrate: Bool = true
    @State private var showDeleteConfirmation = false
    @State private var showExportSheet = false
    @State private var isDirty = false
    @State private var confirmTask: Task<Void, Never>?

    private let avatarOptions = [
        "robot.fill", "rocket.fill", "star.fill", "globe",
        "lightbulb.fill", "brain.head.profile", "wand.and.stars",
        "gamecontroller.fill", "music.note", "camera.fill",
        "paintbrush.fill", "book.fill"
    ]

    public var body: some View {
        NavigationStack {
            Form {
                // Avatar Selection
                Section("Avatar") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(avatarOptions, id: \.self) { avatar in
                                VStack {
                                    Image(systemName: avatar)
                                        .font(.title2.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 56, height: 56)
                                        .background(
                                            selectedAvatar == avatar
                                                ? CompanionPalette.novaBlue
                                                : CompanionPalette.companionBorder
                                        )
                                        .clipShape(Circle())
                                }
                                .contentShape(Circle())
                                .onTapGesture {
                                    selectedAvatar = avatar
                                    isDirty = true
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Profile Information
                Section("Profile") {
                    TextField("Child's Name", text: $childName)
                        .onChange(of: childName) { _, _ in isDirty = true }

                    HStack {
                        Text("Age")
                        Spacer()
                        Stepper(
                            value: $childAge,
                            in: 4...8,
                            label: { Text("\(childAge)") }
                        )
                        .onChange(of: childAge) { _, _ in isDirty = true }
                    }
                }

                // Learning Preferences
                Section("Learning Preferences") {
                    Picker("Preferred Lesson Length", selection: $preferredLessonLength) {
                        Text("Short (5-10 min)").tag("short")
                        Text("Medium (10-20 min)").tag("medium")
                        Text("Long (20+ min)").tag("long")
                    }
                    .onChange(of: preferredLessonLength) { _, _ in isDirty = true }

                    Toggle("Auto-Narrate", isOn: $autoNarrate)
                        .onChange(of: autoNarrate) { _, _ in isDirty = true }
                }

                // Current Stage
                Section("Learning Stage") {
                    HStack {
                        Text("Current Stage")
                        Spacer()
                        Text("Thinker")
                            .fontWeight(.semibold)
                            .foregroundStyle(CompanionPalette.novaBlue)
                    }

                    HStack {
                        Text("Lessons to Next Stage")
                        Spacer()
                        Text("3")
                            .fontWeight(.semibold)
                    }
                }

                // Stats (Read-only)
                Section("Statistics") {
                    HStack {
                        Text("Total Lessons Completed")
                        Spacer()
                        Text("18")
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("Badges Earned")
                        Spacer()
                        Text("8")
                            .fontWeight(.semibold)
                    }

                    HStack {
                        Text("Current Streak")
                        Spacer()
                        Text("5 days")
                            .fontWeight(.semibold)
                    }
                }

                // Data Management
                // Build-fix (Jun 11): `Section("…", footer:)` is not a
                // SwiftUI initializer — header/footer view builders are.
                // (This bad expression type-collapsed the whole Form into
                // the misleading "FormStyleConfiguration" diagnostic.)
                Section(
                    header: Text("Data Management"),
                    footer: Text("COPPA compliance")
                ) {
                    Button(action: { showExportSheet = true }) {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                                .foregroundStyle(CompanionPalette.novaBlue)

                            Text("Export Child Data")
                                .foregroundStyle(CompanionPalette.novaBlue)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption.weight(.semibold))
                        }
                    }

                    Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash.fill")

                            Text("Delete All Child Data")

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
            }
            .navigationTitle("Edit Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveProfile()
                        dismiss()
                    }
                    .disabled(!isDirty)
                }
            }
        }
        .onAppear {
            childName = childProfile.name
            childAge = Calendar.current.dateComponents([.year], from: childProfile.birthDate, to: Date()).year ?? 4
        }
        .confirmationDialog(
            "Delete All Data",
            isPresented: $showDeleteConfirmation,
            presenting: ()
        ) { _ in
            Button("Cancel", role: .cancel) {}

            Button("Delete All Data", role: .destructive) {
                // Show second confirmation
                confirmTask?.cancel()
                confirmTask = Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    guard !Task.isCancelled else { return }
                    showDeleteConfirmation = true
                }
            }
        } message: { _ in
            Text("This action will permanently delete all learning data for \(childName). This cannot be undone.")
        }
        .sheet(isPresented: $showExportSheet) {
            ExportDataView(childName: childName, isPresented: $showExportSheet)
        }
    }

    // MARK: - Actions

    private func saveProfile() {
        childProfile.name = childName
        // In production, call API to update child profile
        isDirty = false
    }
}

// MARK: - Export Data Sheet

struct ExportDataView: View {
    let childName: String
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(CompanionPalette.novaGreen)
                            .font(.title3.weight(.semibold))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Export Ready")
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)

                            Text("Data for \(childName) has been prepared")
                                .font(CompanionPalette.captionFont())
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(CompanionPalette.novaGreen.opacity(0.1))
                    .border(CompanionPalette.novaGreen.opacity(0.3), width: 1)
                    .cornerRadius(8)
                }
                .padding(16)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Included Files")
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)

                    VStack(spacing: 8) {
                        exportFileRow("Profile & Account Data", "profile.json", size: "2.3 KB")
                        exportFileRow("Learning Progress", "progress.json", size: "15.8 KB")
                        exportFileRow("Badges & Achievements", "badges.json", size: "3.1 KB")
                        exportFileRow("Session History", "sessions.json", size: "28.5 KB")
                    }
                    .padding(12)
                    .background(CompanionPalette.companionCard)
                    .border(CompanionPalette.companionBorder, width: 1)
                    .cornerRadius(8)
                    .padding(.horizontal, 16)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(action: { isPresented = false }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download as ZIP")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(CompanionPalette.novaBlue)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                    }

                    Button(action: { isPresented = false }) {
                        Text("Done")
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .foregroundStyle(CompanionPalette.novaBlue)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func exportFileRow(_ name: String, _ filename: String, size: String) -> some View {
        HStack {
            Image(systemName: "doc.fill")
                .foregroundStyle(CompanionPalette.novaBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(CompanionPalette.bodyFont())

                Text(filename)
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(size)
                .font(CompanionPalette.captionFont())
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ChildProfileView(
        childProfile: ChildProfile(
            userId: UUID(),
            name: "Maya",
            birthDate: Date().addingTimeInterval(-126_144_000),
            currentStage: 2
        )
    )
}
