import SwiftUI

/// Reusable classroom-themed loading spinner.
///
/// A sun-tinted arc rotates on top of an ink-ring track, with a small
/// `classroomPaper` disc centered behind it so the spinner reads
/// against any backdrop. Replaces system `ProgressView()` on
/// child-facing surfaces so beta testers never hit a default iOS
/// spinner mid-classroom.
///
/// ## Behavior
///
/// - **Animated** (`accessibilityReduceMotion == false`): the
///   `classroomSun` arc rotates continuously at a calm 1.1s loop.
/// - **Reduce Motion** (`accessibilityReduceMotion == true`): the
///   spinner renders statically as a full sun-tinted ring with a
///   small `classroomSchoolRed` "loading" tick. No rotation, no
///   timer, no schedule. The user still gets a visual loading cue,
///   the kid still gets a calm classroom reading.
///
/// ## Accessibility
///
/// The view is a single `accessibilityElement(children: .ignore)` with
/// label `"Loading"`, optional `accessibilityValue`, and the
/// `.updatesFrequently` trait. Callers can override the value via
/// `caption` (e.g. `"Signing in"`).
///
/// ## Sizing
///
/// `Size` controls both the arc diameter and the stroke weight so the
/// spinner can sit inline next to body copy (`.small`), inside a
/// hero-image placeholder (`.medium`), or on its own loading screen
/// (`.large`) without re-tuning at the call site.
public struct ClassroomSpinner: View {
    public enum Size {
        case small
        case medium
        case large

        var diameter: CGFloat {
            switch self {
            case .small:  return 22
            case .medium: return 36
            case .large:  return 56
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .small:  return 3
            case .medium: return 4
            case .large:  return 5
            }
        }
    }

    private let size: Size
    private let caption: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotating = false

    public init(size: Size = .medium, caption: String? = nil) {
        self.size = size
        self.caption = caption
    }

    public var body: some View {
        ZStack {
            // Soft paper disc behind the ring so the spinner reads
            // against busy artwork (CardHeroImage placeholder, classroom
            // backdrop). Sized just inside the ring so it doesn't
            // dominate when the spinner sits inline.
            Circle()
                .fill(NovaPalette.classroomPaper.opacity(0.92))
                .frame(width: size.diameter - size.lineWidth, height: size.diameter - size.lineWidth)

            // Ink ring track.
            Circle()
                .stroke(NovaPalette.classroomInk.opacity(0.30), lineWidth: size.lineWidth)
                .frame(width: size.diameter, height: size.diameter)

            // Active arc — animates under regular motion, static under
            // Reduce Motion (full ring with a school-red tick at the
            // top instead of a rotating arc).
            if reduceMotion {
                staticIndicator
            } else {
                rotatingArc
            }
        }
        .frame(width: size.diameter, height: size.diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
        .accessibilityValue(caption ?? "")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var rotatingArc: some View {
        Circle()
            .trim(from: 0.0, to: 0.28)
            .stroke(
                NovaPalette.classroomSun,
                style: StrokeStyle(lineWidth: size.lineWidth, lineCap: .round)
            )
            .frame(width: size.diameter, height: size.diameter)
            .rotationEffect(.degrees(rotating ? 360 : 0))
            .animation(
                .linear(duration: 1.1).repeatForever(autoreverses: false),
                value: rotating
            )
            .onAppear { rotating = true }
    }

    private var staticIndicator: some View {
        ZStack {
            Circle()
                .stroke(NovaPalette.classroomSun, lineWidth: size.lineWidth)
                .frame(width: size.diameter, height: size.diameter)

            // Small school-red tick at 12-o'clock so a glance still
            // reads as "an indicator is here" without motion.
            Circle()
                .fill(NovaPalette.classroomSchoolRed)
                .frame(width: size.lineWidth * 1.6, height: size.lineWidth * 1.6)
                .offset(y: -(size.diameter / 2))
        }
    }
}

#Preview("Animated") {
    HStack(spacing: 24) {
        ClassroomSpinner(size: .small)
        ClassroomSpinner(size: .medium)
        ClassroomSpinner(size: .large, caption: "Signing in")
    }
    .padding()
    .background(NovaPalette.classroomChalkboard.opacity(0.18))
}

// To preview the Reduce Motion path, run the app with the simulator's
// `Settings → Accessibility → Motion → Reduce Motion` toggled on.
// `accessibilityReduceMotion` is a read-only environment value and cannot
// be flipped from a `#Preview` block.
