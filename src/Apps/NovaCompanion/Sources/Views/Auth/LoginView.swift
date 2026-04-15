import SwiftUI
import AuthenticationServices
import NovaCore
import NovaAuth

/// Login screen with Sign in with Apple integration.
public struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    public var body: some View {
        ZStack {
            CompanionPalette.companionBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.largeTitle.weight(.light))
                        .foregroundStyle(CompanionPalette.novaBlue)

                    Text("Nova Companion")
                        .font(CompanionPalette.largeTitleFont())
                        .fontWeight(.bold)

                    Text("Empower your child's AI journey")
                        .font(CompanionPalette.secondaryBodyFont())
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 60)
                .padding(.bottom, 40)

                Spacer()

                // Sign in with Apple
                VStack(spacing: 16) {
                    SignInWithAppleButton(
                        onRequest: handleAppleSignInRequest,
                        onCompletion: handleAppleSignInCompletion
                    )
                    .frame(height: 50)
                    .cornerRadius(8)

                    if let errorMessage = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(errorMessage)
                                .font(CompanionPalette.captionFont())
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Footer Links
                VStack(spacing: 12) {
                    Divider()

                    HStack(spacing: 16) {
                        Link("Privacy Policy", destination: URL(string: "https://nova.local/privacy")!)
                            .font(CompanionPalette.captionFont())
                            .foregroundStyle(CompanionPalette.novaBlue)

                        Text("•")
                            .foregroundStyle(.secondary)

                        Link("Terms of Service", destination: URL(string: "https://nova.local/terms")!)
                            .font(CompanionPalette.captionFont())
                            .foregroundStyle(CompanionPalette.novaBlue)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .disabled(isSigningIn)
    }

    private func handleAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    private func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) {
        isSigningIn = true
        errorMessage = nil

        Task {
            do {
                switch result {
                case .success(let authorization):
                    if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                        // Pass to auth manager for Sign in with Apple handling
                        await authManager.handleAppleSignIn(credential: appleIDCredential)
                    }
                case .failure(let error):
                    if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                        errorMessage = "Sign in failed. Please try again."
                    }
                }
            }
            isSigningIn = false
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager(apiClient: .mock()))
}
