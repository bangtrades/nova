import SwiftUI

/// Empty state view shown when no content is available.
///
/// Renders as a classroom paper note pinned to the workbook surface
/// rather than a generic dashboard card, so beta testers never fall out
/// of the classroom metaphor when content is missing. Uses
/// `NovaPalette.classroom*` tokens exclusively (no `novaBlue` /
/// `novaPalette.primary` references) so the empty state speaks the
/// same language as the rest of the lesson chrome.
public struct EmptyStateView: View {
    /// Title text displayed.
    let title: String

    /// Subtitle text displayed below the title.
    let subtitle: String

    /// Optional icon/emoji to display (defaults to sparkles).
    let icon: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    public init(
        title: String = "No lessons yet!",
        subtitle: String = "Ask your parent to add some!",
        icon: String = "sparkles"
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }

    public var body: some View {
        ZStack {
            // Soft chalkboard backdrop so the empty note doesn't sit on
            // a stark white screen. Honors the classroom metaphor without
            // competing with the paper note's ink stroke.
            chalkboardBackdrop
                .ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Spacer(minLength: 0)

                paperNote

                Spacer(minLength: 0)
            }
            .padding(Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle)
        .onAppear {
            // Soft pulse on the icon halo. Reduce-motion gates the
            // animation entirely (`.animation(nil, ...)` below).
            pulse = true
        }
    }

    // MARK: - Subviews

    /// The classroom note. Paper rounded rectangle with an ink stroke,
    /// a sun-tinted icon disc at the top, two pieces of school-red tape
    /// at the corners, title + subtitle as ink copy.
    private var paperNote: some View {
        VStack(spacing: Spacing.md) {
            iconDisc

            Text(title)
                .font(NovaPalette.headingFont())
                .foregroundStyle(NovaPalette.classroomInk)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)

            Text(subtitle)
                .font(NovaPalette.bodyFont())
                .foregroundStyle(NovaPalette.classroomInk.opacity(0.78))
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .minimumScaleFactor(0.85)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: 480)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(NovaPalette.classroomPaper)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(NovaPalette.classroomInk.opacity(0.50), lineWidth: 2)
        }
        .overlay(alignment: .topLeading) { tape(rotation: -10) }
        .overlay(alignment: .topTrailing) { tape(rotation: 10) }
        .shadow(color: NovaPalette.classroomInk.opacity(0.20), radius: 10, x: 0, y: 4)
    }

    /// Sun-tinted icon disc with a soft halo. The halo only animates
    /// when Reduce Motion is off; under Reduce Motion the disc stays
    /// at a calm rest state.
    private var iconDisc: some View {
        ZStack {
            // Halo pulse — sun-tinted ring that gently breathes. Static
            // under Reduce Motion.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            NovaPalette.classroomSun.opacity(0.55),
                            NovaPalette.classroomSun.opacity(0.0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)
                .scaleEffect(reduceMotion ? 1.0 : (pulse ? 1.08 : 0.94))
                .opacity(reduceMotion ? 0.55 : (pulse ? 0.70 : 0.40))
                .animation(
                    reduceMotion
                        ? nil
                        : .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                    value: pulse
                )
                .accessibilityHidden(true)

            // Solid sun disc carrying the system icon.
            Circle()
                .fill(NovaPalette.classroomSun)
                .frame(width: 84, height: 84)
                .overlay {
                    Circle()
                        .stroke(NovaPalette.classroomInk.opacity(0.55), lineWidth: 2)
                }
                .shadow(color: NovaPalette.classroomInk.opacity(0.18), radius: 4, x: 0, y: 2)

            Image(systemName: icon)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(NovaPalette.classroomInk)
                .accessibilityHidden(true)
        }
    }

    /// Small paper-tape sticker at a card corner. Decorative only.
    private func tape(rotation: Double) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(NovaPalette.classroomSchoolRed.opacity(0.78))
            .overlay {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.45), lineWidth: 1)
            }
            .frame(width: 48, height: 14)
            .rotationEffect(.degrees(rotation))
            .offset(y: -7)
            .accessibilityHidden(true)
    }

    /// Chalkboard backdrop shared with the lesson-complete celebration —
    /// keeps the empty state inside the classroom metaphor instead of
    /// dropping onto a generic page background.
    private var chalkboardBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    NovaPalette.classroomChalkboard,
                    NovaPalette.classroomChalkboard.opacity(0.92),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    NovaPalette.classroomChalkDust.opacity(0.18),
                    Color.clear,
                ],
                center: .center,
                startRadius: 60,
                endRadius: 360
            )
            .accessibilityHidden(true)
        }
    }
}

#Preview("Default") {
    EmptyStateView()
}

#Preview("Custom") {
    EmptyStateView(
        title: "Lesson not found",
        subtitle: "Ask a grown-up to refresh your classroom.",
        icon: "questionmark.circle"
    )
}
