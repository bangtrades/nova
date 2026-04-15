import SwiftUI
import NovaCore
import NovaAuth

/// Settings tab with account, subscription, children, LLM providers, and notifications.
public struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingSignOutConfirmation = false
    @State private var selectedChild: ChildProfile?
    @State private var showAddChild = false
    @State private var showingDeleteDataConfirmation = false
    @State private var weeklyReportNotifications = true
    @State private var dailyReminders = true
    @State private var badgeAlerts = true

    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Account Section
                        settingSection(title: "Account") {
                            accountRow(label: "Name", value: "Alex")
                            accountRow(label: "Email", value: "parent@nova-app.com")

                            Button(role: .destructive, action: { showingSignOutConfirmation = true }) {
                                HStack {
                                    Image(systemName: "arrow.backward.circle.fill")
                                    Text("Sign Out")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                                .foregroundStyle(.red)
                            }
                        }

                        // Subscription Section
                        settingSection(title: "Subscription") {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Your Plan")
                                        .font(CompanionPalette.bodyFont())
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 8) {
                                        Text("Pro")
                                            .font(CompanionPalette.headingFont())
                                            .fontWeight(.bold)

                                        TierBadgeView(tier: "Pro")
                                    }
                                }

                                Spacer()

                                NavigationLink(destination: SubscriptionView()) {
                                    HStack(spacing: 4) {
                                        Text("Manage")
                                            .font(CompanionPalette.captionFont())
                                            .fontWeight(.semibold)
                                            .foregroundStyle(CompanionPalette.novaBlue)

                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(CompanionPalette.novaBlue)
                                    }
                                }
                            }
                            .padding(12)

                            Divider()
                                .padding(.horizontal, 12)

                            UsageMeterView(
                                used: 12,
                                total: 50,
                                label: "AI Generations Used"
                            )
                            .padding(0)
                            .background(CompanionPalette.companionCard)
                            .border(Color.clear, width: 0)
                            .cornerRadius(0)
                        }

                        // Children Section
                        settingSection(title: "Children") {
                            VStack(spacing: 0) {
                                childrenListContent
                            }
                        }

                        // App Settings
                        settingSection(title: "App Settings") {
                            NavigationLink(destination: LLMProviderSettingsView()) {
                                settingRowContent(
                                    icon: "cpu.fill",
                                    title: "LLM Providers",
                                    subtitle: "Configure AI models",
                                    color: CompanionPalette.novaBlue
                                )
                            }
                        }

                        // Reports Section
                        settingSection(title: "Reports") {
                            NavigationLink(destination: WeeklyReportView()) {
                                settingRowContent(
                                    icon: "chart.bar.fill",
                                    title: "Weekly Report",
                                    subtitle: "View progress summary and recommendations",
                                    color: CompanionPalette.novaBlue
                                )
                            }
                        }

                        // Notifications Section
                        settingSection(title: "Notifications") {
                            VStack(spacing: 0) {
                                notificationToggleRow(
                                    title: "Weekly Report",
                                    subtitle: "Get a summary of your child's progress",
                                    icon: "envelope.open.fill",
                                    isOn: $weeklyReportNotifications
                                )

                                Divider()
                                    .padding(.horizontal, 12)

                                notificationToggleRow(
                                    title: "Daily Reminders",
                                    subtitle: "Remind your child to practice",
                                    icon: "bell.fill",
                                    isOn: $dailyReminders
                                )

                                Divider()
                                    .padding(.horizontal, 12)

                                notificationToggleRow(
                                    title: "Badge Alerts",
                                    subtitle: "Notify when badges are earned",
                                    icon: "star.fill",
                                    isOn: $badgeAlerts
                                )
                            }
                        }
                        .onChange(of: weeklyReportNotifications) { _, newValue in
                            if newValue {
                                NotificationScheduler.shared.scheduleWeeklyReport()
                            } else {
                                NotificationScheduler.shared.cancel(identifier: "weekly-report")
                            }
                        }

                        // Privacy Section
                        settingSection(title: "Privacy") {
                            Button(action: { showingDeleteDataConfirmation = true }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                        .foregroundStyle(.red)

                                    Text("Delete All Child Data")
                                        .foregroundStyle(.red)

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                            }
                        }

                        // Legal & Support
                        settingSection(title: "Legal & Support") {
                            NavigationLink(destination: LegalDocumentView(type: .privacyPolicy)) {
                                HStack {
                                    Text("Privacy Policy")
                                        .font(CompanionPalette.bodyFont())

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                                .foregroundStyle(.primary)
                            }

                            Divider()
                                .padding(.horizontal, 12)

                            NavigationLink(destination: LegalDocumentView(type: .termsOfService)) {
                                HStack {
                                    Text("Terms of Service")
                                        .font(CompanionPalette.bodyFont())

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                                .foregroundStyle(.primary)
                            }

                            Divider()
                                .padding(.horizontal, 12)

                            Link(destination: URL(string: "mailto:support@nova.app")!) {
                                HStack {
                                    Text("Contact Support")
                                        .font(CompanionPalette.bodyFont())

                                    Spacer()

                                    Image(systemName: "arrow.up.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(CompanionPalette.novaBlue)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 12)
                                .foregroundStyle(CompanionPalette.novaBlue)
                            }
                        }

                        // About
                        settingSection(title: "About") {
                            aboutRow(label: "Version", value: "1.0.0")
                            aboutRow(label: "Build", value: "2025.1")

                            HStack(spacing: 12) {
                                Image(systemName: "info.circle")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(CompanionPalette.novaBlue)

                                Text("Nova Companion — Empower your child's AI learning journey")
                                    .font(CompanionPalette.captionFont())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                        }

                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Sign Out", isPresented: $showingSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out? You can sign back in anytime.")
            }
            .confirmationDialog("Delete All Data", isPresented: $showingDeleteDataConfirmation) {
                Button("Delete", role: .destructive) {
                    // Perform deletion
                }
            } message: {
                Text("This will permanently delete all child learning data. This action cannot be undone.")
            }
        }
    }

    // MARK: - Children List Content

    @ViewBuilder
    private var childrenListContent: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(CompanionPalette.novaBlue)

                Text("No children added yet")
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding(12)
        }
        .background(CompanionPalette.companionCard)
    }

    // MARK: - Helper Views

    @ViewBuilder
    private func settingRowContent(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CompanionPalette.bodyFont())
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func notificationToggleRow(
        title: String,
        subtitle: String,
        icon: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(CompanionPalette.novaBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CompanionPalette.bodyFont())
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(CompanionPalette.captionFont())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func settingSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                content()
            }
            .background(CompanionPalette.companionCard)
            .border(CompanionPalette.companionBorder, width: 1)
            .cornerRadius(8)
            .padding(.horizontal, 16)
        }
    }

    private func accountRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label)
                    .font(CompanionPalette.bodyFont())
                    .foregroundStyle(.secondary)

                Spacer()

                Text(value)
                    .font(CompanionPalette.bodyFont())
                    .fontWeight(.semibold)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)

            Divider()
                .padding(.horizontal, 12)
        }
    }

    private func aboutRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(CompanionPalette.bodyFont())
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(CompanionPalette.bodyFont())
                .fontWeight(.semibold)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager(apiClient: .mock()))
}
