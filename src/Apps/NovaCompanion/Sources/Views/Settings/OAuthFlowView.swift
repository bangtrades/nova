import SwiftUI

/// OAuth flow view for connecting LLM providers.
public struct OAuthFlowView: View {
    @Environment(\.dismiss) var dismiss
    let provider: String
    let onCompletion: (Bool) -> Void

    @State private var isLoading = true
    @State private var success = false
    @State private var errorMessage: String?
    @State private var flowTask: Task<Void, Never>?
    @State private var dismissTask: Task<Void, Never>?

    public var body: some View {
        ZStack {
            CompanionPalette.companionBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                if isLoading {
                    // Loading State
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)

                        VStack(spacing: 8) {
                            Text("Connecting to \(provider)...")
                                .font(CompanionPalette.bodyFont())
                                .fontWeight(.semibold)

                            Text("A verification window will appear shortly")
                                .font(CompanionPalette.captionFont())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                    .onAppear {
                        // Simulate OAuth flow
                        flowTask = Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            guard !Task.isCancelled else { return }
                            withAnimation {
                                success = true
                                isLoading = false
                            }
                        }
                    }
                } else if success {
                    // Success State
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.largeTitle.weight(.semibold))
                                .foregroundStyle(CompanionPalette.statusPublished)

                            VStack(spacing: 8) {
                                Text("Connected Successfully!")
                                    .font(CompanionPalette.headingFont())
                                    .fontWeight(.semibold)

                                Text("Your \(provider) account is now connected")
                                    .font(CompanionPalette.secondaryBodyFont())
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        Button(action: { dismiss(); onCompletion(true) }) {
                            Text("Continue")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(CompanionPalette.novaBlue)
                                .foregroundStyle(.white)
                                .cornerRadius(8)
                        }

                        Spacer()
                    }
                    .padding(32)
                } else if let errorMessage = errorMessage {
                    // Error State
                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.largeTitle.weight(.semibold))
                                .foregroundStyle(.red)

                            VStack(spacing: 8) {
                                Text("Connection Failed")
                                    .font(CompanionPalette.headingFont())
                                    .fontWeight(.semibold)

                                Text(errorMessage)
                                    .font(CompanionPalette.secondaryBodyFont())
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }

                        HStack(spacing: 12) {
                            Button(role: .cancel, action: { dismiss(); onCompletion(false) }) {
                                Text("Cancel")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(CompanionPalette.companionBorder))
                            }

                            Button(action: {
                                isLoading = true
                                // Build-fix (Jun 11): `errorMessage` here is
                                // the immutable `if let` shadow — write the
                                // state property explicitly.
                                self.errorMessage = nil
                                flowTask?.cancel()
                                flowTask = Task {
                                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                                    guard !Task.isCancelled else { return }
                                    withAnimation {
                                        success = true
                                        isLoading = false
                                    }
                                }
                            }) {
                                Text("Retry")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(CompanionPalette.novaBlue)
                                    .foregroundStyle(.white)
                                    .cornerRadius(8)
                            }
                        }

                        Spacer()
                    }
                    .padding(32)
                }
            }
        }
        .onDisappear {
            flowTask?.cancel()
            dismissTask?.cancel()
        }
    }
}

#Preview {
    OAuthFlowView(provider: "OpenAI") { _ in }
}
