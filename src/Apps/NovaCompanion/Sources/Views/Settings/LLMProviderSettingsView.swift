import SwiftUI

/// Settings for LLM provider configuration.
public struct LLMProviderSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var openAIConnected = false
    @State private var showingOAuthFlow = false

    public var body: some View {
        NavigationStack {
            ZStack {
                CompanionPalette.companionBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Available Providers
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Available Providers")
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)
                                .padding(.horizontal, 16)

                            VStack(spacing: 12) {
                                // OpenAI
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("OpenAI")
                                                .font(CompanionPalette.bodyFont())
                                                .fontWeight(.semibold)

                                            if openAIConnected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(CompanionPalette.statusPublished)
                                            }
                                        }

                                        Text(openAIConnected ? "Connected" : "Not connected")
                                            .font(CompanionPalette.captionFont())
                                            .foregroundStyle(openAIConnected ? CompanionPalette.statusPublished : .secondary)
                                    }

                                    Spacer()

                                    if !openAIConnected {
                                        Button(action: { showingOAuthFlow = true }) {
                                            Text("Connect")
                                                .font(CompanionPalette.captionFont())
                                                .fontWeight(.semibold)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(CompanionPalette.novaBlue)
                                                .foregroundStyle(.white)
                                                .cornerRadius(6)
                                        }
                                    } else {
                                        Button(role: .destructive, action: { openAIConnected = false }) {
                                            Text("Disconnect")
                                                .font(CompanionPalette.captionFont())
                                                .fontWeight(.semibold)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.red.opacity(0.3)))
                                        }
                                    }
                                }
                                .padding(12)
                                .background(CompanionPalette.companionCard)
                                .border(CompanionPalette.companionBorder, width: 1)
                                .cornerRadius(8)

                                if openAIConnected {
                                    VStack(alignment: .leading, spacing: 8) {
                                        infoRow(label: "Status", value: "Active")
                                        infoRow(label: "Model", value: "GPT-4o")
                                        infoRow(label: "Last Used", value: "Today at 2:45 PM")
                                        infoRow(label: "Token Expiry", value: "2025-07-13")
                                    }
                                    .padding(12)
                                    .background(CompanionPalette.novaBlue.opacity(0.05))
                                    .border(CompanionPalette.companionBorder, width: 1)
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Coming Soon
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Coming Soon")
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)
                                .padding(.horizontal, 16)

                            VStack(spacing: 8) {
                                providerComingSoon(name: "Anthropic Claude", icon: "sparkles")
                                providerComingSoon(name: "Google Gemini", icon: "globe")
                            }
                            .padding(.horizontal, 16)
                        }

                        // Info
                        HStack(spacing: 12) {
                            Image(systemName: "info.circle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(CompanionPalette.novaBlue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Why connect a provider?")
                                    .font(CompanionPalette.bodyFont())
                                    .fontWeight(.semibold)

                                Text("LLM providers power AI-generated lessons and intelligent content features.")
                                    .font(CompanionPalette.captionFont())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(CompanionPalette.novaBlue.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)

                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("LLM Providers")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingOAuthFlow) {
                OAuthFlowView(provider: "OpenAI") { success in
                    if success {
                        openAIConnected = true
                    }
                    showingOAuthFlow = false
                }
            }
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(CompanionPalette.captionFont())
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(CompanionPalette.captionFont())
                .fontWeight(.semibold)
        }
    }

    private func providerComingSoon(name: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.gray)

            Text(name)
                .font(CompanionPalette.bodyFont())
                .foregroundStyle(.secondary)

            Spacer()

            Text("Coming Soon")
                .font(CompanionPalette.captionFont())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(12)
        .background(CompanionPalette.companionCard)
        .border(CompanionPalette.companionBorder, width: 1)
        .cornerRadius(8)
    }
}

#Preview {
    LLMProviderSettingsView()
}
