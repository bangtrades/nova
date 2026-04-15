import SwiftUI
import NovaCore

/// Comprehensive child progress dashboard showing analytics, charts, and activity.
public struct ProgressDashboardView: View {
    @StateObject private var viewModel = ProgressDashboardViewModel()
    @EnvironmentObject var apiRouter: APIRouter
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var selectedChildId: String = "child-001"
    @State private var isRefreshing = false

    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Child Picker (horizontal scroll)
                        childPickerSection

                        if let analytics = viewModel.analytics {
                            // Adaptive layout based on screen size
                            if horizontalSizeClass == .regular {
                                // iPad: Side-by-side layout
                                HStack(spacing: 16) {
                                    VStack(spacing: 16) {
                                        summaryCardsSection(analytics)
                                        stageProgressSection(analytics)
                                    }

                                    weeklyChartSection(analytics)
                                }
                                .padding(.horizontal, 16)
                            } else {
                                // iPhone: Stacked layout
                                summaryCardsSection(analytics)
                                    .padding(.horizontal, 16)

                                weeklyChartSection(analytics)
                                    .padding(.horizontal, 16)

                                stageProgressSection(analytics)
                                    .padding(.horizontal, 16)
                            }

                            // Badge Summary
                            badgeSummarySection(analytics)
                                .padding(.horizontal, 16)

                            // Recent Activity
                            recentActivitySection(analytics)
                                .padding(.horizontal, 16)
                        }

                        if isLoading {
                            ProgressView()
                                .padding(32)
                        }

                        if let error = viewModel.error {
                            errorBanner(error)
                                .padding(.horizontal, 16)
                        }

                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.vertical, 16)
                }
                .refreshable {
                    isRefreshing = true
                    viewModel.refreshAnalytics()
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    isRefreshing = false
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            viewModel.loadAnalytics(childId: selectedChildId, apiRouter: apiRouter)
        }
    }

    // MARK: - Child Picker Section

    @ViewBuilder
    private var childPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Child")
                .font(CompanionPalette.captionFont())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(["child-001", "child-002"], id: \.self) { childId in
                        VStack(spacing: 6) {
                            Image(systemName: childId == "child-001" ? "person.circle.fill" : "person.circle")
                                .font(.title)
                                .foregroundStyle(
                                    childId == selectedChildId
                                        ? CompanionPalette.novaBlue
                                        : .gray
                                )

                            Text(childId == "child-001" ? "Maya" : "Aiden")
                                .font(CompanionPalette.captionFont())
                                .fontWeight(.semibold)
                        }
                        .frame(width: 60)
                        .padding(8)
                        .background(
                            childId == selectedChildId
                                ? CompanionPalette.novaBlue.opacity(0.1)
                                : Color.clear
                        )
                        .cornerRadius(8)
                        .onTapGesture {
                            selectedChildId = childId
                            viewModel.loadAnalytics(childId: childId, apiRouter: apiRouter)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Summary Cards Section

    @ViewBuilder
    private func summaryCardsSection(_ analytics: ChildAnalytics) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                summaryCard(
                    title: "Lessons",
                    value: "\(analytics.completedLessons)/\(analytics.totalLessons)",
                    icon: "book.fill",
                    color: CompanionPalette.novaBlue
                )

                summaryCard(
                    title: "Completion",
                    value: "\(analytics.completionRate)%",
                    icon: "percent",
                    color: CompanionPalette.novaOrange
                )
            }

            HStack(spacing: 12) {
                summaryCard(
                    title: "Streak",
                    value: "\(analytics.currentStreak) days",
                    icon: "flame.fill",
                    color: CompanionPalette.novaPink
                )

                summaryCard(
                    title: "Badges",
                    value: "\(analytics.badgesEarned)/\(analytics.badgesTotal)",
                    icon: "star.fill",
                    color: CompanionPalette.novaYellow
                )
            }
        }
    }

    // MARK: - Weekly Chart Section

    @ViewBuilder
    private func weeklyChartSection(_ analytics: ChildAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Activity")
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)

            // Bar chart
            HStack(alignment: .bottom, spacing: 6) {
                let maxValue = max(analytics.weeklyHeatmap.max() ?? 1, 1)

                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CompanionPalette.novaBlue)
                            .frame(
                                height: CGFloat(analytics.weeklyHeatmap[index]) / CGFloat(maxValue) * 100
                            )

                        Text(dayInitial(index))
                            .font(CompanionPalette.smallCaptionFont())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120)
            .padding(12)
            .background(CompanionPalette.companionCard)
            .border(CompanionPalette.companionBorder, width: 1)
            .cornerRadius(8)

            // Total time
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(CompanionPalette.novaOrange)
                    .font(.subheadline.weight(.semibold))

                Text("\(analytics.totalTimeMinutes) minutes total this week")
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(12)
            .background(CompanionPalette.companionCard)
            .border(CompanionPalette.companionBorder, width: 1)
            .cornerRadius(8)
        }
    }

    // MARK: - Stage Progress Section

    @ViewBuilder
    private func stageProgressSection(_ analytics: ChildAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Learning Stage")
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(analytics.stageProgress.current)
                        .font(CompanionPalette.headingFont())
                        .fontWeight(.bold)

                    Spacer()

                    Text("\(analytics.stageProgress.lessonsToNext) lessons to next")
                        .font(CompanionPalette.captionFont())
                        .foregroundStyle(.secondary)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(CompanionPalette.companionBorder)

                        let progress = min(
                            Double(analytics.completedLessons) / Double(analytics.totalLessons),
                            1.0
                        )
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        CompanionPalette.novaGreen,
                                        CompanionPalette.novaBlue
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 8)
            }
            .padding(12)
            .background(CompanionPalette.companionCard)
            .border(CompanionPalette.companionBorder, width: 1)
            .cornerRadius(8)
        }
    }

    // MARK: - Badge Summary Section

    @ViewBuilder
    private func badgeSummarySection(_ analytics: ChildAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Earned Badges")
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)

            if analytics.badgesEarned > 0 {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 60), spacing: 8)
                ], spacing: 8) {
                    ForEach(0..<min(analytics.badgesEarned, 12), id: \.self) { _ in
                        VStack(spacing: 4) {
                            Image(systemName: "star.circle.fill")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(CompanionPalette.novaYellow)

                            Text("Badge")
                                .font(CompanionPalette.captionFont())
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(CompanionPalette.companionCard)
                        .border(CompanionPalette.companionBorder, width: 1)
                        .cornerRadius(6)
                    }
                }
            } else {
                EmptyStateView(
                    icon: "star",
                    title: "No Badges Yet",
                    message: "Badges will appear here as your child completes achievements"
                )
            }
        }
    }

    // MARK: - Recent Activity Section

    @ViewBuilder
    private func recentActivitySection(_ analytics: ChildAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)

            VStack(spacing: 0) {
                ForEach(Array(analytics.recentActivity.enumerated()), id: \.element.id) { index, activity in
                    HStack(spacing: 12) {
                        // Timeline line + dot
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle()
                                    .fill(CompanionPalette.companionBorder)
                                    .frame(width: 1)
                                    .frame(height: 8)
                            }

                            Image(systemName: activity.icon)
                                .font(.caption.weight(.semibold))
                                .frame(width: 24, height: 24)
                                .background(activityColor(for: activity.type))
                                .foregroundStyle(.white)
                                .clipShape(Circle())

                            if index < analytics.recentActivity.count - 1 {
                                Rectangle()
                                    .fill(CompanionPalette.companionBorder)
                                    .frame(width: 1)
                                    .frame(height: 8)
                            }
                        }
                        .frame(width: 24)

                        // Content
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.title)
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)

                            Text(relativeTimeString(activity.timestamp))
                                .font(CompanionPalette.captionFont())
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)

                    if index < analytics.recentActivity.count - 1 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
            .background(CompanionPalette.companionCard)
            .border(CompanionPalette.companionBorder, width: 1)
            .cornerRadius(8)
        }
    }

    // MARK: - Helper Views

    private func summaryCard(
        title: String,
        value: String,
        icon: String,
        color: Color
    ) -> some View {
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

    private func errorBanner(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)

            Text(error)
                .font(CompanionPalette.captionFont())
                .foregroundStyle(.red)

            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .border(Color.red.opacity(0.3), width: 1)
        .cornerRadius(8)
    }

    private func dayInitial(_ index: Int) -> String {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        return days[index]
    }

    private func activityColor(for type: String) -> Color {
        switch type {
        case "lesson_completed":
            return CompanionPalette.novaGreen
        case "badge_earned":
            return CompanionPalette.novaYellow
        case "experiment_passed":
            return CompanionPalette.novaPurple
        case "voice_chat":
            return CompanionPalette.novaOrange
        default:
            return CompanionPalette.novaBlue
        }
    }

    private func relativeTimeString(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }

    private var isLoading: Bool {
        viewModel.isLoading
    }
}

#Preview {
    ProgressDashboardView()
        .environmentObject(APIRouter(apiClient: .mock()))
}
