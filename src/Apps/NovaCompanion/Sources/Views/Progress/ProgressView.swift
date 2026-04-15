import SwiftUI

/// Detailed progress analytics tab.
public struct ProgressTabView: View {
    @StateObject private var viewModel = ProgressViewModel()

    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Child Selector
                        if viewModel.children.count > 1 {
                            Picker("Select Child", selection: $viewModel.selectedChildId) {
                                ForEach(viewModel.children) { child in
                                    Text(child.name).tag(Optional(child.id))
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 16)
                        }

                        // Activity Chart
                        ProgressChartView(activities: viewModel.weeklyActivity)
                            .padding(.horizontal, 16)

                        // Stats Summary
                        HStack(spacing: 12) {
                            statCard(
                                title: "Lessons Completed",
                                value: "\(viewModel.lessonsCompleted)",
                                icon: "book.fill",
                                color: CompanionPalette.novaBlue
                            )

                            statCard(
                                title: "Avg Session",
                                value: "\(viewModel.averageSessionDuration)m",
                                icon: "clock.fill",
                                color: CompanionPalette.novaOrange
                            )
                        }
                        .padding(.horizontal, 16)

                        // Badges Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Badges Earned")
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)

                            if viewModel.badgesEarned.isEmpty {
                                EmptyStateView(
                                    icon: "star",
                                    title: "No Badges Yet",
                                    message: "Badges will appear here as your child completes achievements"
                                )
                            } else {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.badgesEarned) { badge in
                                        VStack(spacing: 6) {
                                            Image(systemName: "star.circle.fill")
                                                .font(.title.weight(.semibold))
                                                .foregroundStyle(CompanionPalette.novaYellow)

                                            Text(formatDate(badge.earnedAt))
                                                .font(CompanionPalette.captionFont())
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(12)
                                        .background(CompanionPalette.companionCard)
                                        .border(CompanionPalette.companionBorder, width: 1)
                                        .cornerRadius(8)
                                    }

                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // Session History
                        SessionHistoryView(sessions: viewModel.sessionHistory)
                            .padding(.horizontal, 16)

                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(color)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(CompanionPalette.headingFont())
                    .fontWeight(.bold)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(CompanionPalette.companionCard)
        .border(CompanionPalette.companionBorder, width: 1)
        .cornerRadius(8)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#Preview {
    ProgressTabView()
}
