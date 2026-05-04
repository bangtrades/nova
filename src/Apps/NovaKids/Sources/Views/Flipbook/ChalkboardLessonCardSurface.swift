import SwiftUI

public enum ChalkboardLessonCardKind: String, CaseIterable, Identifiable {
    case story
    case concept
    case quiz
    case experiment
    case voice

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .story:
            "Story"
        case .concept:
            "Concept"
        case .quiz:
            "Quiz"
        case .experiment:
            "Experiment"
        case .voice:
            "Voice"
        }
    }

    var symbolName: String {
        switch self {
        case .story:
            "doc.text.fill"
        case .concept:
            "lightbulb.fill"
        case .quiz:
            "questionmark.circle.fill"
        case .experiment:
            "wrench.and.screwdriver.fill"
        case .voice:
            "mic.fill"
        }
    }

    var materialDescription: String {
        switch self {
        case .story:
            "Pinned paper on the chalkboard"
        case .concept:
            "Chalk diagram surface"
        case .quiz:
            "Magnetic tile surface"
        case .experiment:
            "Tabletop activity surface"
        case .voice:
            "Teacher prompt surface"
        }
    }

    var defaultAccent: Color {
        switch self {
        case .story:
            NovaPalette.classroomSchoolRed
        case .concept:
            NovaPalette.classroomSun
        case .quiz:
            NovaPalette.classroomPurple
        case .experiment:
            NovaPalette.classroomLeaf
        case .voice:
            NovaPalette.classroomSky
        }
    }

    var surfaceFill: Color {
        switch self {
        case .story, .concept:
            NovaPalette.classroomChalkboard
        case .quiz:
            NovaPalette.classroomPaper
        case .experiment:
            NovaPalette.classroomWood
        case .voice:
            NovaPalette.classroomPaper
        }
    }

    var contentFill: Color {
        switch self {
        case .story, .quiz, .voice:
            NovaPalette.classroomPaper
        case .concept:
            NovaPalette.classroomChalkboard.opacity(0.92)
        case .experiment:
            NovaPalette.classroomWood.opacity(0.78)
        }
    }

    var primaryText: Color {
        switch self {
        case .story, .concept:
            NovaPalette.classroomChalkDust
        case .quiz, .experiment, .voice:
            NovaPalette.classroomInk
        }
    }
}

public struct ChalkboardLessonCardSurface<Content: View>: View {
    private let cardKind: ChalkboardLessonCardKind
    private let title: String
    private let accent: Color
    private let content: Content

    public init(
        cardKind: ChalkboardLessonCardKind,
        title: String,
        accent: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.cardKind = cardKind
        self.title = title
        self.accent = accent ?? cardKind.defaultAccent
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header

            contentPanel
        }
        .padding(Spacing.lg)
        .background(backgroundSurface)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.md, style: .continuous))
        .overlay(border)
        .shadow(color: NovaPalette.classroomInk.opacity(0.18), radius: 12, x: 0, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityHint(Text(cardKind.materialDescription))
    }

    private var header: some View {
        Label {
            Text(title)
                .font(.title3.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        } icon: {
            Image(systemName: cardKind.symbolName)
                .font(.title3.weight(.bold))
                .imageScale(.medium)
        }
        .foregroundStyle(cardKind.primaryText)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule(style: .continuous)
                .fill(accent.opacity(0.24))
        )
        .accessibilityAddTraits(.isHeader)
    }

    private var contentPanel: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: Spacing.md, style: .continuous)
                .fill(cardKind.contentFill)

            materialAccent
                .accessibilityHidden(true)

            content
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.md, style: .continuous)
                .stroke(accent.opacity(0.55), lineWidth: 2)
        )
    }

    private var backgroundSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Spacing.md, style: .continuous)
                .fill(cardKind.surfaceFill)

            backgroundTexture
                .accessibilityHidden(true)
        }
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: Spacing.md, style: .continuous)
            .strokeBorder(accent.opacity(0.8), lineWidth: 3)
    }

    @ViewBuilder
    private var backgroundTexture: some View {
        switch cardKind {
        case .story:
            StoryPins(accent: accent)
        case .concept:
            ChalkDiagram(accent: accent)
        case .quiz:
            QuizMagnets(accent: accent)
        case .experiment:
            TabletopGrain(accent: accent)
        case .voice:
            VoiceBadge(accent: accent)
        }
    }

    @ViewBuilder
    private var materialAccent: some View {
        switch cardKind {
        case .story:
            Circle()
                .fill(accent)
                .frame(width: Spacing.md, height: Spacing.md)
                .padding(Spacing.md)
        case .concept:
            Capsule(style: .continuous)
                .fill(NovaPalette.classroomChalkDust.opacity(0.5))
                .frame(width: 72, height: 6)
                .rotationEffect(.degrees(-8))
                .padding(Spacing.md)
        case .quiz:
            RoundedRectangle(cornerRadius: Spacing.xs, style: .continuous)
                .fill(accent.opacity(0.85))
                .frame(width: Spacing.xl, height: Spacing.xl)
                .rotationEffect(.degrees(4))
                .padding(Spacing.md)
        case .experiment:
            Rectangle()
                .fill(accent.opacity(0.34))
                .frame(height: Spacing.sm)
                .padding(.top, Spacing.md)
        case .voice:
            Circle()
                .fill(accent.opacity(0.34))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: cardKind.symbolName)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(accent)
                )
                .padding(Spacing.md)
        }
    }
}

private struct StoryPins: View {
    let accent: Color

    var body: some View {
        HStack {
            Circle()
                .fill(accent.opacity(0.85))
                .frame(width: Spacing.md, height: Spacing.md)

            Spacer()

            Circle()
                .fill(accent.opacity(0.85))
                .frame(width: Spacing.md, height: Spacing.md)
        }
        .padding(Spacing.lg)
    }
}

private struct ChalkDiagram: View {
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(0..<3, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(NovaPalette.classroomChalkDust.opacity(0.24))
                    .frame(width: CGFloat(92 + index * 28), height: 5)
            }

            Circle()
                .stroke(accent.opacity(0.42), lineWidth: 3)
                .frame(width: 84, height: 84)
                .offset(x: 56)
        }
        .padding(Spacing.lg)
    }
}

private struct QuizMagnets: View {
    let accent: Color

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: Spacing.xs, style: .continuous)
                    .fill(index.isMultiple(of: 2) ? accent.opacity(0.5) : NovaPalette.classroomSun.opacity(0.5))
                    .frame(width: Spacing.xl, height: Spacing.xl)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -6 : 6))
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

private struct TabletopGrain: View {
    let accent: Color

    var body: some View {
        VStack(spacing: Spacing.md) {
            ForEach(0..<4, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill((index.isMultiple(of: 2) ? accent : NovaPalette.classroomInk).opacity(0.16))
                    .frame(height: 4)
            }
        }
        .padding(Spacing.lg)
    }
}

private struct VoiceBadge: View {
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.2))
                .frame(width: 112, height: 112)

            Circle()
                .stroke(accent.opacity(0.32), lineWidth: 3)
                .frame(width: 88, height: 88)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }
}

#Preview("Chalkboard lesson card surfaces") {
    ScrollView {
        LazyVStack(spacing: Spacing.lg) {
            ForEach(ChalkboardLessonCardKind.allCases) { kind in
                ChalkboardLessonCardSurface(
                    cardKind: kind,
                    title: "\(kind.displayName) card"
                ) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(kind.materialDescription)
                            .font(.headline)

                        Text("Future lesson content can sit inside this reusable classroom surface.")
                            .font(.body)
                    }
                    .foregroundStyle(kind.primaryText)
                }
            }
        }
        .padding(Spacing.lg)
    }
    .background(NovaPalette.classroomPaper)
}
