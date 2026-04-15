import SwiftUI
import NovaCore

/// Card displaying a child's profile information.
public struct ChildProfileCard: View {
    let child: ChildProfile
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false

    private var stageInfo: (stage: ChildProfile.Stage, color: Color) {
        let stage = ChildProfile.Stage(rawValue: child.currentStage) ?? .explorer
        let colors: [ChildProfile.Stage: Color] = [
            .explorer: CompanionPalette.novaBlue,
            .thinker: CompanionPalette.novaOrange,
            .maker: CompanionPalette.novaPurple,
            .creator: CompanionPalette.novaGreen,
        ]
        return (stage: stage, color: colors[stage] ?? CompanionPalette.novaBlue)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Avatar and Name
            HStack(spacing: 12) {
                ZStack {
                    stageInfo.color.opacity(0.2)
                        .frame(width: 64, height: 64)
                        .cornerRadius(12)

                    Image(systemName: "figure.child.circle.fill")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(stageInfo.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(child.name)
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)

                    Text("Age \(child.age)")
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Learning Stage Badge
            VStack(alignment: .leading, spacing: 6) {
                Text("Learning Stage")
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)

                HStack {
                    Image(systemName: stageBadgeIcon(stageInfo.stage))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(stageInfo.color)

                    Text(stageInfo.stage.displayName)
                        .font(CompanionPalette.bodyFont())
                        .fontWeight(.semibold)

                    Spacer()

                    Text(stageInfo.stage.description)
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(8)
                .background(stageInfo.color.opacity(0.1))
                .cornerRadius(6)
            }

            // Stats Row
            HStack(spacing: 16) {
                statItem(label: "Sessions", value: "7", icon: "play.circle.fill")
                statItem(label: "Time", value: "2h 14m", icon: "clock.fill")
                statItem(label: "Badges", value: "3", icon: "star.fill")
            }
        }
        .padding(16)
        .background(CompanionPalette.companionCard)
        .border(CompanionPalette.companionBorder, width: 1)
        .cornerRadius(12)
        .confirmationDialog("Delete Child Profile", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete \"\(child.name)\"'s profile? This cannot be undone.")
        }
    }

    private func statItem(label: String, value: String, icon: String) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(stageInfo.color)

            Text(value)
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)

            Text(label)
                .font(CompanionPalette.captionFont())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func stageBadgeIcon(_ stage: ChildProfile.Stage) -> String {
        switch stage {
        case .explorer:
            return "binoculars.fill"
        case .thinker:
            return "lightbulb.fill"
        case .maker:
            return "hammer.fill"
        case .creator:
            return "star.fill"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ChildProfileCard(
            child: ChildProfile(
                userId: UUID(),
                name: "Explorer",
                birthDate: Calendar.current.date(byAdding: .year, value: -4, to: Date()) ?? Date(),
                currentStage: 1
            ),
            onEdit: {},
            onDelete: {}
        )

        ChildProfileCard(
            child: ChildProfile(
                userId: UUID(),
                name: "Maker",
                birthDate: Calendar.current.date(byAdding: .year, value: -7, to: Date()) ?? Date(),
                currentStage: 3
            ),
            onEdit: {},
            onDelete: {}
        )
    }
    .padding(16)
    .background(CompanionPalette.companionBackground)
}
