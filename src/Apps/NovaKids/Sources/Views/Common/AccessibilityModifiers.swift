import SwiftUI
import UIKit

// MARK: - View Extensions for Accessibility

public extension View {
    /// Applies Nova accessibility label, hint, and trait.
    func novaAccessible(
        label: String,
        hint: String? = nil,
        trait: AccessibilityTraits = .isButton
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(trait)
    }

    /// Ensures text respects Dynamic Type and minimum sizes.
    func novaDynamicType() -> some View {
        self
            .dynamicTypeSize(.xSmall ... .accessibility5)
    }

    /// Adds high-contrast border when accessibility settings enabled.
    func novaHighContrast() -> some View {
        modifier(HighContrastModifier())
    }

    /// Replaces animations with crossfade when Reduce Motion is enabled.
    func novaReduceMotion() -> some View {
        modifier(ReduceMotionModifier())
    }
}

// MARK: - Modifiers

private struct HighContrastModifier: ViewModifier {
    @Environment(\.legibilityWeight) var legibilityWeight

    func body(content: Content) -> some View {
        if legibilityWeight == .bold {
            content
                .border(Color.primary, width: 2)
        } else {
            content
        }
    }
}

private struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
                .transaction { transaction in
                    transaction.animation = .easeInOut(duration: 0.2)
                }
        } else {
            content
        }
    }
}

// MARK: - Palette Accessibility Extensions

public extension NovaPalette {
    /// Returns high-contrast variant of a color for accessibility.
    static func accessibleColor(_ color: Color) -> Color {
        // Simple high-contrast mapping: darker/brighter versions
        switch color {
        case NovaPalette.novaBlue:
            return Color(red: 0.0, green: 0.35, blue: 0.75) // Darker blue
        case NovaPalette.novaOrange:
            return Color(red: 0.95, green: 0.4, blue: 0.0) // Darker orange
        case NovaPalette.novaPurple:
            return Color(red: 0.5, green: 0.0, blue: 0.7) // Darker purple
        case NovaPalette.novaGreen:
            return Color(red: 0.0, green: 0.55, blue: 0.0) // Darker green
        case NovaPalette.novaPink:
            return Color(red: 1.0, green: 0.2, blue: 0.2) // Darker pink
        case NovaPalette.novaYellow:
            return Color(red: 0.95, green: 0.75, blue: 0.0) // Darker yellow
        default:
            return color
        }
    }
}

// MARK: - Accessibility Announcement Manager

/// Manages VoiceOver announcements for the app.
@MainActor
public class AccessibilityAnnouncementManager: NSObject {
    /// Singleton instance.
    public static let shared = AccessibilityAnnouncementManager()

    private override init() {
        super.init()
    }

    /// Posts an accessibility announcement.
    /// - Parameter message: The message to announce.
    public func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    /// Announces a page or section change.
    /// - Parameter pageName: The name of the new page/section.
    public func announcePageChange(_ pageName: String) {
        let message = "You're now on \(pageName)"
        UIAccessibility.post(notification: .pageScrolled, argument: message)
    }

    /// Announces a success action (e.g., lesson completed).
    /// - Parameter action: Description of the completed action.
    public func announceSuccess(_ action: String) {
        announce("\(action). Great job!")
    }

    /// Announces an error (e.g., network failure).
    /// - Parameter error: Description of the error.
    public func announceError(_ error: String) {
        announce("Error: \(error). Please try again.")
    }
}

// MARK: - Common Accessibility Labels

public struct AccessibilityLabels {
    /// Button labels
    static let playLesson = "Play lesson"
    static let nextPage = "Next page"
    static let previousPage = "Previous page"
    static let closeModal = "Close"
    static let retry = "Retry"
    static let back = "Go back"

    /// Card labels
    static func lessonCard(_ title: String) -> String {
        "Lesson: \(title)"
    }

    static func progressCard(_ current: Int, _ total: Int) -> String {
        "\(current) of \(total) lessons completed"
    }

    static func badgeCard(_ name: String) -> String {
        "Badge earned: \(name)"
    }

    /// Status labels
    static func loadingStatus(_ item: String) -> String {
        "Loading \(item)"
    }

    static func completedStatus(_ item: String) -> String {
        "\(item) completed"
    }

    static func errorStatus(_ message: String) -> String {
        "Error: \(message)"
    }

    /// Interactive elements
    static func avatarButton(_ avatar: String) -> String {
        "Choose \(avatar) avatar"
    }

    static func difficultyLevel(_ level: String) -> String {
        "\(level) difficulty"
    }

    static func progressSlider(_ percent: Int) -> String {
        "\(percent) percent complete"
    }
}

// MARK: - VoiceOver-Optimized View Wrapper

/// Wraps content with comprehensive accessibility labels and hints.
public struct AccessibilityWrapper<Content: View>: View {
    let label: String
    let hint: String?
    let content: () -> Content

    public init(
        label: String,
        hint: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.label = label
        self.hint = hint
        self.content = content
    }

    public var body: some View {
        content()
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
}

// MARK: - Accessible Button

/// Button with enhanced accessibility for children.
public struct AccessibleButton: View {
    let label: String
    let action: () -> Void
    let content: () -> AnyView

    public init(
        label: String,
        action: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> AnyView
    ) {
        self.label = label
        self.action = action
        self.content = content
    }

    public var body: some View {
        Button(action: action) {
            content()
        }
        .novaAccessible(label: label)
    }
}

#Preview {
    VStack(spacing: 24) {
        Text("Accessible Text")
            .novaDynamicType()
            .novaAccessible(label: "Title text")

        Button(action: {}) {
            Text("Accessible Button")
                .frame(maxWidth: .infinity)
                .padding()
                .background(NovaPalette.novaOrange)
                .foregroundStyle(.white)
                .cornerRadius(8)
        }
        .novaAccessible(label: "Primary action button", hint: "Tap to perform action")

        AccessibilityWrapper(label: "Progress indicator", hint: "3 of 8 lessons completed") {
            ProgressView(value: 0.375)
                .tint(NovaPalette.novaOrange)
        }

        Spacer()
    }
    .padding()
    .background(NovaPalette.novaBackground)
}
