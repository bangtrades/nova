import SwiftUI
import NovaCore

/// Modal form for adding a new child profile.
public struct AddChildView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name: String = ""
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -5, to: Date()) ?? Date()
    @State private var selectedIcon: String = "figure.child"
    let onSave: (ChildProfile) -> Void

    private let childIcons = ["figure.child", "figure.child.circle.fill", "person.crop.circle.fill"]

    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar Selection
                        VStack(alignment: .center, spacing: 12) {
                            Text("Choose an Avatar")
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)

                            HStack(spacing: 16) {
                                ForEach(childIcons, id: \.self) { icon in
                                    Button(action: { selectedIcon = icon }) {
                                        Image(systemName: icon)
                                            .font(.title.weight(.semibold))
                                            .foregroundStyle(selectedIcon == icon ? CompanionPalette.novaBlue : .gray)
                                            .frame(width: 60, height: 60)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(
                                                        selectedIcon == icon ? CompanionPalette.novaBlue : Color.clear,
                                                        lineWidth: 2
                                                    )
                                            )
                                    }
                                }
                                Spacer()
                            }
                        }
                        .padding(16)
                        .background(CompanionPalette.companionCard)
                        .border(CompanionPalette.companionBorder, width: 1)
                        .cornerRadius(8)

                        // Form Fields
                        VStack(alignment: .leading, spacing: 16) {
                            textField(label: "Child's Name", text: $name, placeholder: "e.g., Emma")

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Birth Date")
                                    .font(CompanionPalette.captionFont())
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)

                                DatePicker(
                                    "Birth Date",
                                    selection: $birthDate,
                                    displayedComponents: [.date]
                                )
                                .datePickerStyle(.graphical)
                                .padding(8)
                                .background(CompanionPalette.companionCard)
                                .border(CompanionPalette.companionBorder, width: 1)
                                .cornerRadius(8)
                                .labelsHidden()
                            }
                            .padding(16)
                            .background(CompanionPalette.companionCard)
                            .border(CompanionPalette.companionBorder, width: 1)
                            .cornerRadius(8)

                            // Age Display
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(CompanionPalette.novaBlue)

                                Text("Age: \(calculateAge())")
                                    .font(CompanionPalette.bodyFont())
                                    .fontWeight(.semibold)

                                Spacer()
                            }
                            .padding(12)
                            .background(CompanionPalette.novaBlue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding(16)
                        .background(CompanionPalette.companionCard)
                        .border(CompanionPalette.companionBorder, width: 1)
                        .cornerRadius(8)

                        Spacer()
                    }
                    .padding(.vertical, 16)
                }

                // Action Buttons
                VStack(spacing: 0) {
                    Divider()

                    HStack(spacing: 12) {
                        Button(role: .cancel, action: { dismiss() }) {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(CompanionPalette.companionBorder))
                        }

                        Button(action: saveChild) {
                            Text("Add Child")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(name.isEmpty ? Color.gray.opacity(0.5) : CompanionPalette.novaBlue)
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                        }
                        .disabled(name.isEmpty)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Add Child")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func textField(label: String, text: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(CompanionPalette.captionFont())
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .font(CompanionPalette.bodyFont())
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.white)
                .border(CompanionPalette.companionBorder, width: 1)
                .cornerRadius(6)
        }
    }

    private func calculateAge() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: birthDate, to: Date())
        return components.year ?? 0
    }

    private func saveChild() {
        let newChild = ChildProfile(
            userId: UUID(),
            name: name,
            birthDate: birthDate,
            currentStage: 1
        )
        onSave(newChild)
        dismiss()
    }
}

#Preview {
    AddChildView(onSave: { _ in })
}
