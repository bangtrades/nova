import SwiftUI
import NovaAuth
import AuthenticationServices

/// Kid-friendly Apple Sign In login screen with fun branding.
///
/// Features:
/// - Large, colorful Nova logo with animated background
/// - "Sign in with Apple" button (ASAuthorizationAppleIDButton)
/// - Friendly tagline and on-error handling
/// - COPPA-compliant (Apple Sign In only)
public struct KidsLoginView: View {
    @StateObject private var viewModel: AuthViewModel
    @State private var showError = false
    @State private var errorMessage = ""

    public init() {
        _viewModel = StateObject(wrappedValue: AuthViewModel())
    }

    public var body: some View {
        ZStack {
            // Animated background with floating shapes
            AnimatedBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(maxHeight: .infinity)

                // Nova Logo and Branding
                VStack(spacing: 16) {
                    // Large colorful Nova logo
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(
                                        colors: [
                                            NovaPalette.novaBlue,
                                            NovaPalette.novaPurple
                                        ]
                                    ),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)

                        VStack(spacing: 2) {
                            Image(systemName: "sparkles")
                                .font(.largeTitle.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Nova")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.bottom, 8)

                    Text("Nova Kids")
                        .font(NovaPalette.titleFont())
                        .foregroundStyle(.primary)

                    Text("Let's learn about AI together!")
                        .font(NovaPalette.largeBodyFont())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                Spacer()
                    .frame(maxHeight: .infinity)

                // Sign In Button
                VStack(spacing: 24) {
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = []
                        },
                        onCompletion: { result in
                            handleSignInResult(result)
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 56)
                    .cornerRadius(14)

                    if viewModel.isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(NovaPalette.novaBlue)
                            Text("Signing in...")
                                .font(NovaPalette.bodyFont())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .alert("Oops! Let's try again", isPresented: $showError) {
            Button("OK") {
                showError = false
                errorMessage = ""
            }
        } message: {
            Text(errorMessage)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nova Kids Sign In")
    }

    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // Get the user identifier (required for COPPA)
                let userIdentifier = appleIDCredential.user

                Task {
                    await viewModel.signInWithApple(userIdentifier: userIdentifier)
                }
            }

        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "We couldn't sign you in. Please try again."
                showError = true
            }
        }
    }
}

// MARK: - Animated Background

/// Floating shape animation for background.
private struct AnimatedBackgroundView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(
                    colors: [
                        NovaPalette.novaBackground,
                        Color(red: 0.95, green: 0.96, blue: 1.0)
                    ]
                ),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Floating shapes
            VStack {
                HStack {
                    Circle()
                        .fill(NovaPalette.novaBlue.opacity(0.15))
                        .frame(width: 100)
                        .offset(y: isAnimating ? -20 : 20)

                    Spacer()

                    RoundedRectangle(cornerRadius: 20)
                        .fill(NovaPalette.novaOrange.opacity(0.15))
                        .frame(width: 80, height: 80)
                        .offset(y: isAnimating ? 20 : -20)
                }
                .padding(.horizontal, -40)

                Spacer()

                HStack {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(NovaPalette.novaPurple.opacity(0.15))
                        .frame(width: 70, height: 70)
                        .offset(y: isAnimating ? 20 : -20)

                    Spacer()

                    Circle()
                        .fill(NovaPalette.novaGreen.opacity(0.15))
                        .frame(width: 90)
                        .offset(y: isAnimating ? -20 : 20)
                }
                .padding(.horizontal, -40)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 3.5)
                    .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    KidsLoginView()
}
