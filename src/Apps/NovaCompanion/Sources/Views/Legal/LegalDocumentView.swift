import SwiftUI
import NovaCore

/// Privacy policy and Terms of Service viewer with print support.
public struct LegalDocumentView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = false
    @State private var documentContent: String = ""
    @State private var scrollPosition: CGFloat = 0
    @State private var showBackToTop = false
    @State private var loadTask: Task<Void, Never>?

    let type: LegalDocumentType
    let lastUpdatedDate = "April 13, 2025"

    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                    } else {
                        scrollableContent
                    }

                    // Back to Top Button
                    if showBackToTop {
                        backToTopButton
                            .transition(.move(edge: .bottom))
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { printDocument() }) {
                            Label("Print", systemImage: "printer.fill")
                        }
                        Button(action: { shareDocument() }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(CompanionPalette.novaBlue)
                    }
                }
            }
            .onAppear {
                loadDocument()
            }
            .onDisappear {
                loadTask?.cancel()
            }
        }
    }

    @ViewBuilder
    private var scrollableContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(navigationTitle)
                        .font(CompanionPalette.titleFont())
                        .fontWeight(.bold)

                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text("Last Updated: \(lastUpdatedDate)")
                            .font(CompanionPalette.captionFont())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // Content with expandable sections
                VStack(spacing: 12) {
                    ForEach(documentSections, id: \.title) { section in
                        LegalDocumentSection(section: section)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).origin.y
                        )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                showBackToTop = value < -200
            }
        }
        .coordinateSpace(name: "scroll")
    }

    @ViewBuilder
    private var backToTopButton: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button(action: { scrollToTop() }) {
                    Image(systemName: "arrowshape.up.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(CompanionPalette.novaBlue)
                        .clipShape(Circle())
                }
                .padding(20)
            }
        }
    }

    private var navigationTitle: String {
        switch type {
        case .privacyPolicy:
            return "Privacy Policy"
        case .termsOfService:
            return "Terms of Service"
        }
    }

    private var documentSections: [DocumentSection] {
        switch type {
        case .privacyPolicy:
            return privacyPolicySections
        case .termsOfService:
            return termsOfServiceSections
        }
    }

    // MARK: - Privacy Policy Sections

    private var privacyPolicySections: [DocumentSection] {
        [
            DocumentSection(
                title: "1. Introduction",
                content: "Nova Companion respects your privacy and is committed to protecting your personal data. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.\n\nPlease read this Privacy Policy carefully. If you do not agree with our policies and practices, please do not use our Services."
            ),
            DocumentSection(
                title: "2. Information We Collect",
                content: "We collect information you provide directly:\n• Account information (name, email, authentication credentials)\n• Child profile information (name, age, avatar preferences)\n• Learning activity and progress data\n• Content created (lessons, notes, feedback)\n\nWe also collect certain information automatically:\n• Device information (model, OS version)\n• App usage data and analytics\n• IP address and location information"
            ),
            DocumentSection(
                title: "3. How We Use Your Information",
                content: "We use collected information to:\n• Provide, maintain, and improve our Services\n• Send you service-related announcements\n• Respond to your inquiries and support requests\n• Generate personalized learning recommendations\n• Comply with legal obligations\n• Prevent fraud and enhance security"
            ),
            DocumentSection(
                title: "4. Children's Privacy (COPPA)",
                content: "Nova Companion is designed for children ages 4-8 and complies with the Children's Online Privacy Protection Act (COPPA). We do not knowingly collect personal information from children under 13 without verifiable parental consent.\n\nParents retain all rights to their child's personal information and can request access, correction, or deletion at any time."
            ),
            DocumentSection(
                title: "5. Data Security",
                content: "We implement comprehensive security measures including:\n• Encryption of data in transit and at rest\n• Regular security audits and penetration testing\n• Access controls and authentication protocols\n• Secure API endpoints with token-based authentication\n\nHowever, no method of transmission over the internet is 100% secure."
            ),
            DocumentSection(
                title: "6. Your Rights",
                content: "You have the right to:\n• Access your personal data\n• Correct inaccurate information\n• Delete your account and associated data\n• Opt-out of non-essential communications\n• Data portability\n\nTo exercise these rights, contact us at privacy@nova-app.local"
            ),
            DocumentSection(
                title: "7. Contact Us",
                content: "If you have questions about this Privacy Policy, please contact us at:\n\nEmail: privacy@nova-app.local\nAddress: Nova Learning, Inc.\nEffective Date: January 1, 2025"
            ),
        ]
    }

    // MARK: - Terms of Service Sections

    private var termsOfServiceSections: [DocumentSection] {
        [
            DocumentSection(
                title: "1. Acceptance of Terms",
                content: "By accessing and using Nova Companion, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service."
            ),
            DocumentSection(
                title: "2. License to Use",
                content: "Nova grants you a limited, non-exclusive, revocable license to use Nova Companion for personal, non-commercial purposes. You may not:\n• Reproduce, modify, or distribute the app or content\n• Reverse engineer or attempt to derive source code\n• Remove any proprietary notices or labels\n• Use the app for commercial purposes without permission"
            ),
            DocumentSection(
                title: "3. User Responsibilities",
                content: "As a user, you agree to:\n• Provide accurate and complete registration information\n• Maintain the confidentiality of your account\n• Use the app in compliance with all applicable laws\n• Not interfere with or disrupt the app's functionality\n• Respect intellectual property and privacy rights"
            ),
            DocumentSection(
                title: "4. Content Ownership",
                content: "You retain ownership of content you create. By using Nova Companion, you grant Nova a worldwide, royalty-free license to use your content to provide and improve our Services.\n\nNova retains ownership of all app code, designs, and pre-created educational content."
            ),
            DocumentSection(
                title: "5. Limitation of Liability",
                content: "To the fullest extent permitted by law, Nova shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including lost profits or data loss, arising from your use of or inability to use the app."
            ),
            DocumentSection(
                title: "6. Disclaimer of Warranties",
                content: "Nova Companion is provided 'as is' without warranties of any kind. We disclaim all warranties, express or implied, including merchantability, fitness for a particular purpose, and non-infringement."
            ),
            DocumentSection(
                title: "7. Third-Party Services",
                content: "Nova Companion may integrate with third-party services (e.g., OpenAI API). Your use of these services is governed by their respective terms. Nova is not responsible for third-party content or services."
            ),
            DocumentSection(
                title: "8. Termination",
                content: "Nova may terminate your account and access to the app at any time, with or without cause. You may terminate your account by deleting the app and requesting account deletion through Settings."
            ),
            DocumentSection(
                title: "9. Contact Information",
                content: "For questions about these Terms of Service:\n\nEmail: legal@nova-app.local\nAddress: Nova Learning, Inc.\nEffective Date: January 1, 2025"
            ),
        ]
    }

    // MARK: - Private Methods

    private func loadDocument() {
        isLoading = true
        loadTask?.cancel()
        loadTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            isLoading = false
        }
    }

    private func scrollToTop() {
        withAnimation {
            // This would require a ScrollViewReader in production
            showBackToTop = false
        }
    }

    private func printDocument() {
        let printInfo = UIPrintInfo(dictionary: [:])
        printInfo.outputType = .general
        printInfo.jobName = navigationTitle

        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo

        let formatter = UISimpleTextPrintFormatter(text: documentSections.map { "\($0.title)\n\n\($0.content)" }.joined(separator: "\n\n"))
        printController.printFormatter = formatter
        printController.present(animated: true)
    }

    private func shareDocument() {
        let shareText = "\(navigationTitle)\n\nLast Updated: \(lastUpdatedDate)\n\nFor more information, visit: https://nova-app.local"

        let activityViewController = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
}

// MARK: - Supporting Views

public struct LegalDocumentSection: View {
    let section: DocumentSection
    @State private var isExpanded = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: $isExpanded) {
                Text(section.content)
                    .font(CompanionPalette.bodyFont())
                    .lineSpacing(2)
                    .foregroundStyle(.primary)
                    .padding(.vertical, 12)
            } label: {
                Text(section.title)
                    .font(CompanionPalette.bodyFont())
                    .fontWeight(.semibold)
            }
        }
        .padding(12)
        .background(CompanionPalette.companionCard)
        .border(CompanionPalette.companionBorder, width: 1)
        .cornerRadius(8)
    }
}

public struct DocumentSection {
    let title: String
    let content: String
}

public enum LegalDocumentType {
    case privacyPolicy
    case termsOfService
}

// MARK: - Preferences

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    LegalDocumentView(type: .privacyPolicy)
}
