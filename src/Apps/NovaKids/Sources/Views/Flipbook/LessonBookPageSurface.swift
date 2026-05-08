import SwiftUI
import UIKit

/// A reusable "book page" paper panel used **inside** lesson card
/// content. Renders as a paper-tinted rounded rectangle with a soft
/// classroom-ink stroke and drop-shadow, so a stretch of body text or
/// a small diagram reads as a page from a picture book / workbook
/// rather than a generic UI card.
///
/// This is **not** a top-level card surface. Story and concept
/// cards no longer nest a chalkboard surface — they render directly
/// inside the `LessonBookReaderShell` workbook chrome. The page
/// surface here is a content-level panel that sits *inside* that
/// shell as a paper note tucked into the open book.
///
/// Two presets:
///
/// - `.storybook` — picture-book page: warm paper fill, generous
///   padding, larger corner radius. Use for narrative copy on
///   `StoryCardView`.
/// - `.workbook` — workbook / lesson-note page: paper fill with a
///   faint left margin rule (school-red, low-opacity), tighter
///   corners. Use for the "big idea" explanation on `ConceptCardView`.
///
/// All padding, corners, palette, and shadow values are derived from
/// `Spacing` and `NovaPalette.classroom*` tokens; no hard-coded
/// colors or numerics that fight the rest of the classroom look.
public struct LessonBookPageSurface<Content: View>: View {
    public enum Mood {
        case storybook
        case workbook
    }

    private let mood: Mood
    private let content: Content

    public init(
        mood: Mood = .storybook,
        @ViewBuilder content: () -> Content
    ) {
        self.mood = mood
        self.content = content()
    }

    public var body: some View {
        content
            .padding(contentPadding)
            .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .leading)
            .background(pageBackground)
            .overlay(alignment: .leading) {
                if mood == .workbook && hasLessonPageAsset == false {
                    // Faint left margin rule like a notebook page.
                    Rectangle()
                        .fill(NovaPalette.classroomSchoolRed.opacity(0.20))
                        .frame(width: 2)
                        .padding(.vertical, Spacing.sm)
                        .padding(.leading, Spacing.md)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .overlay {
                if hasLessonPageAsset == false {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(NovaPalette.classroomInk.opacity(0.45), lineWidth: 1.5)
                }
            }
            .shadow(color: NovaPalette.classroomInk.opacity(0.14), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private var pageBackground: some View {
        if let assetName {
            Image(assetName)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(NovaPalette.classroomPaper)
        }
    }

    /// Resolves the painted page asset for the current `mood` via
    /// `LessonArtSlot`. Returns `nil` when no candidate is in the
    /// bundle, in which case the surface falls back to its SwiftUI
    /// paper rendering.
    private var assetName: String? {
        switch mood {
        case .storybook:
            return LessonArtSlot.bookPageStorybook.resolvedName
        case .workbook:
            return LessonArtSlot.bookPageWorkbook.resolvedName
        }
    }

    private var hasLessonPageAsset: Bool {
        assetName != nil
    }

    private var cornerRadius: CGFloat {
        switch mood {
        case .storybook: return 18
        case .workbook: return 14
        }
    }

    private var contentPadding: CGFloat {
        switch mood {
        case .storybook: return Spacing.lg
        case .workbook: return Spacing.md
        }
    }

    private var minimumHeight: CGFloat {
        switch mood {
        case .storybook: return 144
        case .workbook: return 132
        }
    }
}

#Preview("Storybook page") {
    LessonBookPageSurface(mood: .storybook) {
        Text("Once upon a time, a curious child asked, “How do computers learn?” She wondered if they had little eyes.")
            .font(NovaPalette.largeBodyFont())
            .foregroundStyle(NovaPalette.classroomInk)
    }
    .padding(Spacing.lg)
    .background(NovaPalette.classroomPaper)
}

#Preview("Workbook page") {
    LessonBookPageSurface(mood: .workbook) {
        Text("AI learns by looking at many examples and finding patterns.")
            .font(NovaPalette.largeBodyFont())
            .foregroundStyle(NovaPalette.classroomInk)
    }
    .padding(Spacing.lg)
    .background(NovaPalette.classroomPaper)
}
