import SwiftUI
import NovaCore

/// Trophy room displaying earned and locked badges.
///
/// Shows badge grid with earned badges in full color and locked badges in grayscale.
/// Includes streak counter and pull-to-refresh functionality.
public struct TrophyRoomView: View {
    @StateObject private var viewModel = TrophyRoomViewModel()
    @State private var selectedBadge: TrophyRoomViewModel.BadgeDisplayItem? = nil
    @State private var showBadgeDetail = false

    @Environment(\.colorScheme) var colorScheme

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    public var body: some View {
        NavigationStack {
            ZStack {
                NovaPalette.novaBackground
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("My Trophies")
                                        .font(NovaPalette.headingFont())
                                        .foregroundStyle(.primary)

                                    HStack(spacing: 4) {
                                        Image(systemName: "flame.fill")
                                            .font(.body)
                                            .foregroundStyle(NovaPalette.novaOrange)

                                        Text("\(viewModel.currentStreak) Days")
                                            .font(NovaPalette.bodyFont())
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(viewModel.badges.filter { $0.isEarned }.count)")
                                        .font(NovaPalette.headingFont())
                                        .foregroundStyle(NovaPalette.novaYellow)

                                    Text("Badges Earned")
                                        .font(NovaPalette.captionFont())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(16)
                            .background(NovaPalette.novaCardBackground)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                        // Stats row
                        HStack(spacing: 12) {
                            StatCard(
                                icon: "book.fill",
                                label: "Lessons",
                                value: "\(viewModel.totalLessonsCompleted)",
                                color: NovaPalette.novaBlue
                            )

                            StatCard(
                                icon: "star.fill",
                                label: "Level",
                                value: "Explorer",
                                color: NovaPalette.novaYellow
                            )

                            StatCard(
                                icon: "checkmark.circle.fill",
                                label: "Completed",
                                value: "\(viewModel.badges.filter { $0.isEarned }.count)/\(viewModel.badges.count)",
                                color: NovaPalette.novaGreen
                            )
                        }
                        .padding(.horizontal, 20)

                        // Badges section
                        if !viewModel.badges.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Achievements")
                                    .font(NovaPalette.headingFont())
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 20)

                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(viewModel.badges) { item in
                                        BadgeView(
                                            earned: item.isEarned,
                                            badge: item.badge,
                                            progress: item.progress,
                                            earnedDate: item.earnedDate
                                        )
                                        .onTapGesture {
                                            selectedBadge = item
                                            showBadgeDetail = true
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        } else {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "trophy.circle.fill")
                                    .font(.largeTitle.weight(.semibold))
                                    .foregroundStyle(NovaPalette.novaYellow.opacity(0.3))

                                VStack(spacing: 8) {
                                    Text("No Badges Yet")
                                        .font(NovaPalette.headingFont())
                                        .foregroundStyle(.primary)

                                    Text("Complete lessons to earn badges!")
                                        .font(NovaPalette.bodyFont())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                        }

                        Spacer(minLength: 24)
                    }
                }
                .refreshable {
                    await viewModel.refreshBadges()
                }
            }
            .navigationTitle("Trophies")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showBadgeDetail) {
                if let badge = selectedBadge {
                    BadgeDetailSheet(item: badge)
                }
            }
        }
    }
}

/// Stat card showing a single metric.
private struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)

            Text(value)
                .font(NovaPalette.headingFont())
                .foregroundStyle(.primary)

            Text(label)
                .font(NovaPalette.captionFont())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

/// Detail sheet for a selected badge.
private struct BadgeDetailSheet: View {
    let item: TrophyRoomViewModel.BadgeDisplayItem

    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                NovaPalette.novaBackground
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Large badge display
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(
                                    item.isEarned
                                        ? LinearGradient(
                                            gradient: Gradient(colors: [
                                                NovaPalette.novaYellow,
                                                NovaPalette.novaOrange,
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        : LinearGradient(
                                            gradient: Gradient(colors: [
                                                NovaPalette.ink.opacity(0.2),
                                                NovaPalette.ink.opacity(0.1),
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                )

                            if item.isEarned {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: [
                                                NovaPalette.novaYellow.opacity(0.3),
                                                Color.clear,
                                            ]),
                                            center: .center,
                                            startRadius: 80,
                                            endRadius: 150
                                        )
                                    )
                                    .blur(radius: 12)
                            }

                            Image(systemName: item.badge.icon)
                                .font(.largeTitle.weight(.semibold))
                                .foregroundStyle(item.isEarned ? .white : NovaPalette.ink.opacity(0.3))
                        }
                        .frame(width: 160, height: 160)

                        VStack(spacing: 12) {
                            Text(item.badge.title)
                                .font(NovaPalette.headingFont())
                                .foregroundStyle(.primary)

                            Text(item.badge.description)
                                .font(NovaPalette.bodyFont())
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            if item.isEarned {
                                if let earnedDate = item.earnedDate {
                                    HStack(spacing: 4) {
                                        Image(systemName: "calendar")
                                            .font(.caption)

                                        Text(formatDate(earnedDate))
                                            .font(NovaPalette.captionFont())
                                    }
                                    .foregroundStyle(.secondary)
                                }
                            } else {
                                VStack(spacing: 8) {
                                    ProgressView(value: Double(item.progress))
                                        .tint(NovaPalette.novaBlue)

                                    HStack {
                                        Text("Progress: \(Int(item.progress * 100))%")
                                            .font(NovaPalette.bodyFont())

                                        Spacer()

                                        Text(unlockedCriteria)
                                            .font(NovaPalette.bodyFont())
                                    }
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(24)
                    .background(NovaPalette.novaCardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)

                    Spacer()

                    Button(action: {
                        dismiss()
                    }) {
                        Text("Close")
                            .font(.title3.weight(.semibold))
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                colorScheme == .dark
                                    ? NovaPalette.novaBlue.opacity(0.25)
                                    : NovaPalette.novaBlue.opacity(0.15)
                            )
                            .foregroundStyle(NovaPalette.novaBlue)
                            .cornerRadius(12)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Badge Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var unlockedCriteria: String {
        let criteria = item.badge.criteria
        switch criteria.type {
        case .lessonsCompleted:
            return "Complete \(criteria.count) lessons"
        case .experimentsCompleted:
            return "Complete \(criteria.count) experiments"
        case .daysStreak:
            return "\(criteria.count) day streak"
        case .voiceInteractions:
            return "\(criteria.count) voice responses"
        case .pathCompleted:
            return "Complete \(criteria.count) learning path"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

#Preview {
    TrophyRoomView()
}
