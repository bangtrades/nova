import SwiftUI

enum LessonReadAloudButtonState: Equatable {
    case idle
    case reading
    case unavailable
}

struct LessonReadAloudButton: View {
    let state: LessonReadAloudButtonState
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if state == .reading && reduceMotion == false {
                    Circle()
                        .fill(NovaPalette.classroomSky.opacity(0.24))
                        .frame(width: 118, height: 118)
                        .scaleEffect(pulse ? 1.12 : 0.94)
                        .animation(
                            .easeInOut(duration: 0.75).repeatForever(autoreverses: true),
                            value: pulse
                        )
                        .accessibilityHidden(true)
                }

                HStack(spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(iconFill)
                            .overlay {
                                Circle()
                                    .stroke(NovaPalette.classroomInk, lineWidth: 2)
                            }
                            .shadow(
                                color: NovaPalette.classroomInk.opacity(0.20),
                                radius: 4,
                                x: 0,
                                y: 2
                            )

                        Image(systemName: iconName)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(NovaPalette.classroomInk)
                            .accessibilityHidden(true)
                    }
                    .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(NovaPalette.bodyFont().weight(.black))
                            .foregroundStyle(NovaPalette.classroomInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(subtitle)
                            .font(NovaPalette.captionFont().weight(.heavy))
                            .foregroundStyle(NovaPalette.classroomInk.opacity(0.72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
                .padding(.leading, Spacing.sm)
                .padding(.trailing, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(buttonBackground)
            }
            .frame(minWidth: 176, minHeight: 88)
        }
        .buttonStyle(.plain)
        .opacity(isEnabled || state == .unavailable ? 1.0 : 0.55)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .onAppear {
            pulse = true
        }
    }

    private var buttonBackground: some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(NovaPalette.classroomPaper)
            .overlay {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(NovaPalette.classroomInk, lineWidth: 2.5)
            }
            .shadow(color: NovaPalette.classroomInk.opacity(0.18), radius: 8, x: 0, y: 4)
    }

    private var iconFill: Color {
        switch state {
        case .idle:
            return NovaPalette.classroomSun
        case .reading:
            return NovaPalette.classroomSky
        case .unavailable:
            return NovaPalette.classroomSchoolRed.opacity(0.70)
        }
    }

    private var iconName: String {
        switch state {
        case .idle:
            return "speaker.wave.2.fill"
        case .reading:
            return "stop.fill"
        case .unavailable:
            return "exclamationmark"
        }
    }

    private var title: String {
        switch state {
        case .idle:
            return "Read page"
        case .reading:
            return "Stop"
        case .unavailable:
            return "Try again"
        }
    }

    private var subtitle: String {
        switch state {
        case .idle:
            return "Dashy reads"
        case .reading:
            return "Reading now"
        case .unavailable:
            return "No words yet"
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .idle:
            return "Read this page aloud"
        case .reading:
            return "Stop reading"
        case .unavailable:
            return "Read aloud unavailable"
        }
    }

    private var accessibilityHint: String {
        switch state {
        case .idle:
            return "Plays the words on this lesson page."
        case .reading:
            return "Stops Dashy from reading this page."
        case .unavailable:
            return "This page does not have readable lesson text yet."
        }
    }
}
