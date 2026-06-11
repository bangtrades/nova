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

            // S12-01: cap the login column at a button-width measure (480pt)
            // so the Sign-In-with-Apple button doesn't stretch to a 1366pt
            // landscape iPad bar. Double-frame pattern — inner cap then
            // outer maxWidth: .infinity centers the capped column. On
            // iPhone the 480 cap is a no-op (viewport is ~390pt).
            VStack(spacing: 0) {
                Spacer()
                    .frame(maxHeight: .infinity)

                // Nova Logo and Branding
                VStack(spacing: Spacing.md) {
                    // Brand mark dressed for the classroom beta: school-red →
                    // sun warm gradient over a classroom-ink outline so the
                    // first impression reads as a sticker pinned to the
                    // classroom door. Inner sparkles + "Nova" wordmark stay in
                    // classroom ink.
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(
                                        colors: [
                                            NovaPalette.classroomSchoolRed,
                                            NovaPalette.classroomSun,
                                        ]
                                    ),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .overlay(
                                Circle()
                                    .stroke(NovaPalette.classroomInk, lineWidth: 2)
                            )
                            .shadow(color: NovaPalette.classroomInk.opacity(0.20), radius: 6, x: 0, y: 3)

                        VStack(spacing: 2) {
                            Image(systemName: "sparkles")
                                .font(.largeTitle.weight(.semibold))
                                .foregroundStyle(NovaPalette.classroomInk)
                            Text("Nova")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(NovaPalette.classroomInk)
                        }
                    }
                    .padding(.bottom, Spacing.sm)

                    Text("Nova Kids")
                        .font(NovaPalette.titleFont())
                        .foregroundStyle(.primary)

                    Text("Let's learn about AI together!")
                        .font(NovaPalette.largeBodyFont())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Spacing.xl)

                Spacer()
                    .frame(maxHeight: .infinity)

                // Sign In Button
                VStack(spacing: Spacing.lg) {
                    // Sign In with Apple keeps its native ASAuthorization styling
                    // — per Apple HIG we don't re-skin this button, so the ink
                    // outline pattern doesn't apply here. The palette flip
                    // surrounds it; the button itself stays stock.
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
                        HStack(spacing: Spacing.sm) {
                            ClassroomSpinner(size: .small, caption: "Signing in")
                            Text("Signing in...")
                                .font(NovaPalette.bodyFont())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xxl)
            }
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
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

                // Contract fix (Jun 10): the backend's /auth/apple also
                // requires the identity token; name + email only arrive
                // on the FIRST authorization, so pass them when present.
                let identityToken = appleIDCredential.identityToken
                    .flatMap { String(data: $0, encoding: .utf8) } ?? ""
                let displayName = appleIDCredential.fullName.map {
                    PersonNameComponentsFormatter().string(from: $0)
                }
                let email = appleIDCredential.email

                Task {
                    await viewModel.signInWithApple(
                        userIdentifier: userIdentifier,
                        identityToken: identityToken,
                        displayName: displayName?.isEmpty == false ? displayName : nil,
                        email: email
                    )
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

/// Floating shape animation for the login backdrop, dressed as a
/// classroom paper backdrop with school-material accents.
///
/// Surface uses `classroomPaper` so the login screen reads as a sheet
/// of warm paper before the kid signs in. The four floating shapes
/// pull from `classroomInk` (subtle ink dots), `classroomSchoolRed`
/// (warm tape sticker), and `classroomSun` (sun sticker) — same
/// classroom-sticker family as the rest of the workbook chrome.
///
/// Reduce-motion: when the user has "Reduce Motion" enabled in iOS
/// accessibility, we skip the `repeatForever(autoreverses: true)`
/// loop entirely and render the shapes in their neutral (offset: 0)
/// resting pose.
private struct AnimatedBackgroundView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Warm paper surface so the login backdrop reads as the
            // same classroom-paper material the rest of the app uses
            // (lesson book pages, error banners, empty-state notes).
            NovaPalette.classroomPaper

            // Floating school-material accents.
            VStack {
                HStack {
                    Circle()
                        .fill(NovaPalette.classroomInk.opacity(0.08))
                        .frame(width: 100)
                        .offset(y: isAnimating ? -20 : 20)

                    Spacer()

                    RoundedRectangle(cornerRadius: 20)
                        .fill(NovaPalette.classroomSchoolRed.opacity(0.20))
                        .frame(width: 80, height: 80)
                        .offset(y: isAnimating ? 20 : -20)
                }
                .padding(.horizontal, -Spacing.xxl)

                Spacer()

                HStack {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(NovaPalette.classroomInk.opacity(0.06))
                        .frame(width: 70, height: 70)
                        .offset(y: isAnimating ? 20 : -20)

                    Spacer()

                    Circle()
                        .fill(NovaPalette.classroomSun.opacity(0.34))
                        .frame(width: 90)
                        .offset(y: isAnimating ? -20 : 20)
                }
                .padding(.horizontal, -Spacing.xxl)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            // Reduce-motion: keep shapes at rest. Doing this in onAppear
            // (not at declaration time) is deliberate — @Environment is
            // only valid inside body/onAppear, and a future toggle
            // while the view is on screen should still win without
            // re-mounting.
            guard !reduceMotion else { return }
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
