import SwiftUI
import NovaCore

/// Dashboard tab showing overview of child progress and recent activity.
public struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var apiRouter: APIRouter
    @State private var showingWelcome = false
    @State private var showingURLIntake = false

    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Welcome Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Good \(timeOfDayGreeting()), \(viewModel.parentName)")
                                .font(CompanionPalette.largeTitleFont())
                                .fontWeight(.bold)

                            Text("Here's what your children have been learning")
                                .font(CompanionPalette.secondaryBodyFont())
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        // Quick Stats Grid
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                QuickStatsCard(
                                    title: "Lessons Published",
                                    value: "\(viewModel.quickStats.lessonsPublished)",
                                    icon: "book.fill",
                                    color: CompanionPalette.novaBlue
                                )

                                QuickStatsCard(
                                    title: "Learning Time",
                                    value: "\(viewModel.quickStats.totalLearningMinutes) min",
                                    icon: "clock.fill",
                                    color: CompanionPalette.novaOrange
                                )
                            }

                            HStack(spacing: 12) {
                                QuickStatsCard(
                                    title: "Badges Earned",
                                    value: "\(viewModel.quickStats.badgesEarned)",
                                    icon: "star.fill",
                                    color: CompanionPalette.novaYellow
                                )

                                QuickStatsCard(
                                    title: "Active Streak",
                                    value: "\(viewModel.quickStats.activeStreak) days",
                                    icon: "flame.fill",
                                    color: CompanionPalette.novaPink
                                )
                            }
                        }
                        .padding(.horizontal, 16)

                        // View Progress Link
                        NavigationLink(destination: ProgressDashboardView()) {
                            HStack(spacing: 12) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.headline)
                                    .foregroundStyle(CompanionPalette.novaBlue)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Comprehensive Progress")
                                        .font(CompanionPalette.bodyFont())
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)

                                    Text("Detailed analytics and activity")
                                        .font(CompanionPalette.captionFont())
                                        .foregroundStyle(.secondary)
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
                        .padding(.horizontal, 16)

                        // Activity Feed
                        ActivityFeedView(items: viewModel.activityFeed)
                            .padding(.horizontal, 16)

                        Spacer()
                            .frame(height: 20)
                    }
                }

                // Quick Add Floating Button with menu
                VStack {
                    Spacer()

                    HStack {
                        Spacer()

                        Menu {
                            Button(action: { showingWelcome = true }) {
                                Label("Manual Lesson", systemImage: "pencil.and.list.clipboard")
                            }

                            Button(action: { showingURLIntake = true }) {
                                Label("From URL", systemImage: "link")
                            }
                        } label: {
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
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingWelcome) {
                WelcomeView()
            }
            .sheet(isPresented: $showingURLIntake) {
                URLIntakeView(apiRouter: apiRouter)
            }
        }
    }

    private func timeOfDayGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "morning"
        } else if hour < 17 {
            return "afternoon"
        } else {
            return "evening"
        }
    }
}

#Preview {
    DashboardView()
        .preferredColorScheme(nil)
}
