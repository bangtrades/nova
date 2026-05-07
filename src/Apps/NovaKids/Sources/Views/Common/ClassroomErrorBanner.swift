import SwiftUI

/// Shared classroom-toned error banner used across NovaKids surfaces
/// (Home, Lessons, Trophies, Flipbook, EnhancedHome).
///
/// Before this view existed, each of those screens defined its own
/// private `errorBanner(message:)` function that drifted in palette
/// (some still on the legacy `coral`/`ink`/`page` tokens, others on
/// `classroom*`), in stroke weight, and in accessibility label
/// phrasing. Centralizing the surface here means a single change to
/// the workbook palette propagates everywhere a kid (or parent) would
/// see "Try Again" in the classroom.
///
/// ## Visual contract
///
/// - `classroomPaper` rounded rectangle (14pt) as the bed.
/// - `classroomInk` 2pt stroke as the page edge.
/// - `classroomSchoolRed` `exclamationmark.triangle.fill` glyph (the
///   standard classroom alert tone), hidden from VoiceOver.
/// - `classroomInk` body text capped to 2 lines.
/// - `Try Again` button uses the existing `.novaSecondary()` style so
///   the action language stays consistent with every other secondary
///   action in the app.
///
/// ## Accessibility
///
/// The banner registers as a single combined element with the
/// announcement `"Error loading <context>: <message>"`. Callers pass
/// `context` (`"home"`, `"trophies"`, `"lessons"`, `"cards"`, etc.)
/// so VoiceOver users hear a surface-specific announcement instead of
/// a generic "Error" cue.
public struct ClassroomErrorBanner: View {
    private let message: String
    private let context: String
    private let retry: () -> Void

    public init(
        message: String,
        context: String,
        retry: @escaping () -> Void
    ) {
        self.message = message
        self.context = context
        self.retry = retry
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(NovaPalette.classroomSchoolRed)
                .accessibilityHidden(true)

            Text(message)
                .font(NovaPalette.captionFont())
                .foregroundStyle(NovaPalette.classroomInk)
                .lineLimit(2)

            Spacer(minLength: Spacing.sm)

            Button("Try Again") {
                retry()
            }
            .novaSecondary()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NovaPalette.classroomPaper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(NovaPalette.classroomInk, lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error loading \(context): \(message)")
    }
}

#Preview {
    VStack(spacing: Spacing.md) {
        ClassroomErrorBanner(
            message: "Couldn't reach the classroom server.",
            context: "home"
        ) { }

        ClassroomErrorBanner(
            message: "The trophy shelf is offline.",
            context: "trophies"
        ) { }
    }
    .padding(Spacing.lg)
    .background(NovaPalette.classroomChalkboard.opacity(0.18))
}
