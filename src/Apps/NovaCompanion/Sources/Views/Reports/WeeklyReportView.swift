import SwiftUI
import NovaCore

/// Auto-generated weekly activity summary for parents.
public struct WeeklyReportView: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @StateObject private var viewModel = WeeklyReportViewModel()
    @State private var showingShareSheet = false
    @State private var shareText: String = ""

    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.2)
                } else if let report = viewModel.report {
                    reportContent(report)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Weekly Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { shareReport() }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(CompanionPalette.novaBlue)
                    }
                }
            }
            .onAppear {
                viewModel.loadReport()
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheetView(items: [shareText])
            }
        }
    }

    @ViewBuilder
    private func reportContent(_ report: WeeklyReport) -> some View {
        if horizontalSizeClass == .regular {
            HStack(spacing: 20) {
                ScrollView {
                    leftColumnContent(report)
                }
                .frame(maxWidth: .infinity)

                ScrollView {
                    rightColumnContent(report)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    leftColumnContent(report)
                    rightColumnContent(report)
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private func leftColumnContent(_ report: WeeklyReport) -> some View {
        VStack(spacing: 20) {
            // Header with date range
            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly Report")
                    .font(CompanionPalette.titleFont())
                    .fontWeight(.bold)

                Text(report.dateRange)
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)
            }

            // Child picker if multiple children
            if !report.childName.isEmpty {
                childPickerRow
            }

            // Summary section
            summaryGrid(report)

            // Highlight section
            highlightCard(report)
        }
    }

    @ViewBuilder
    private func rightColumnContent(_ report: WeeklyReport) -> some View {
        VStack(spacing: 20) {
            // Activity breakdown chart
            activityBreakdownSection(report)

            // Comparison with last week
            comparisonSection(report)

            // Recommendations
            recommendationsSection(report)

            Spacer()
        }
    }

    @ViewBuilder
    private var childPickerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Child")
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)

            Picker("Child", selection: $viewModel.selectedChildId) {
                Text("All Children").tag(String?.none)
                Text(viewModel.report?.childName ?? "Child").tag(Optional("1"))
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(CompanionPalette.companionCard)
        .border(CompanionPalette.companionBorder, width: 1)
        .cornerRadius(8)
    }

    @ViewBuilder
    private func summaryGrid(_ report: WeeklyReport) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                summaryCard(
                    title: "Lessons Completed",
                    value: "\(report.lessonsCompleted)",
                    icon: "book.fill",
                    color: CompanionPalette.novaBlue
                )

                summaryCard(
                    title: "Learning Time",
                    value: "\(report.totalMinutes) min",
                    icon: "clock.fill",
                    color: CompanionPalette.novaOrange
                )
            }

            HStack(spacing: 12) {
                summaryCard(
                    title: "New Badges",
                    value: "\(report.newBadges)",
                    icon: "star.fill",
                    color: CompanionPalette.novaYellow
                )

                summaryCard(
                    title: "Streak",
                    value: "\(report.currentStreak) days",
                    icon: "flame.fill",
                    color: CompanionPalette.novaPink
                )
            }
        }
    }

    @ViewBuilder
    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)

                Text(title)
                    .font(CompanionPalette.captionFont())
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text(value)
                .font(CompanionPalette.headingFont())
                .fontWeight(.bold)
        }
        .padding(12)
        .background(CompanionPalette.companionCard)
        .border(CompanionPalette.companionBorder, width: 1)
        .cornerRadius(8)
    }

    @ViewBuilder
    private func highlightCard(_ report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundStyle(CompanionPalette.novaYellow)

                Text("This Week's Achievement")
                    .font(CompanionPalette.bodyFont())
                    .fontWeight(.semibold)

                Spacer()
            }

            Text(report.highlight)
                .font(CompanionPalette.bodyFont())
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding(12)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(UIColor.systemYellow).opacity(0.1),
                    Color(UIColor.systemOrange).opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .border(CompanionPalette.novaYellow.opacity(0.3), width: 1)
        .cornerRadius(8)
    }

    @ViewBuilder
    private func activityBreakdownSection(_ report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Breakdown")
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ForEach(report.weeklyBreakdown, id: \.activityType) { item in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.color)
                            .frame(width: 12, height: 12)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.activityType)
                                .font(CompanionPalette.bodyFont())

                            Text("\(Int(item.percentage))%")
                                .font(CompanionPalette.captionFont())
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(item.minutes) min")
                            .font(CompanionPalette.bodyFont())
                            .fontWeight(.semibold)
                    }

                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.color.opacity(0.3))
                            .frame(height: 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(item.color)
                                    .frame(width: geometry.size.width * item.percentage / 100)
                                , alignment: .leading
                            )
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(12)
        .background(CompanionPalette.companionCard)
        .border(CompanionPalette.companionBorder, width: 1)
        .cornerRadius(8)
    }

    @ViewBuilder
    private func comparisonSection(_ report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("vs Last Week")
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)

            VStack(spacing: 12) {
                comparisonRow(
                    label: "Lessons Completed",
                    current: report.vsLastWeek.lessonsChange,
                    percentage: report.vsLastWeek.lessonsPercentage
                )

                comparisonRow(
                    label: "Learning Time",
                    current: report.vsLastWeek.timeChange,
                    percentage: report.vsLastWeek.timePercentage
                )

                comparisonRow(
                    label: "Badges Earned",
                    current: report.vsLastWeek.badgesChange,
                    percentage: report.vsLastWeek.badgesPercentage
                )
            }
        }
        .padding(12)
        .background(CompanionPalette.companionCard)
        .border(CompanionPalette.companionBorder, width: 1)
        .cornerRadius(8)
    }

    @ViewBuilder
    private func comparisonRow(label: String, current: String, percentage: Double) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(CompanionPalette.bodyFont())

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: percentage >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(percentage >= 0 ? CompanionPalette.novaGreen : .red)

                Text(String(format: "%.0f%%", abs(percentage)))
                    .font(CompanionPalette.captionFont())
                    .fontWeight(.semibold)
                    .foregroundStyle(percentage >= 0 ? CompanionPalette.novaGreen : .red)
            }
        }
    }

    @ViewBuilder
    private func recommendationsSection(_ report: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next Steps")
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                ForEach(report.recommendations.prefix(3), id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CompanionPalette.novaOrange)
                            .frame(width: 20)
                            .padding(.top, 2)

                        Text(recommendation)
                            .font(CompanionPalette.captionFont())
                            .lineLimit(3)

                        Spacer()
                    }
                }
            }
        }
        .padding(12)
        .background(CompanionPalette.companionCard)
        .border(CompanionPalette.companionBorder, width: 1)
        .cornerRadius(8)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No data yet")
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)

            Text("Reports appear once your child starts learning")
                .font(CompanionPalette.captionFont())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CompanionPalette.companionBackground)
    }

    private func shareReport() {
        shareText = viewModel.shareText
        showingShareSheet = true
    }
}

#Preview {
    WeeklyReportView()
}
