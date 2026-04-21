import SwiftUI

/// Loading skeleton view for progressive content display.
///
/// Shows animated placeholder blocks while content is loading.
public struct LoadingSkeletonView: View {
    /// Number of skeleton items to display.
    let itemCount: Int

    /// Whether to show as a masonry grid (true) or vertical list (false).
    let isGrid: Bool

    public init(itemCount: Int = 6, isGrid: Bool = true) {
        self.itemCount = itemCount
        self.isGrid = isGrid
    }

    public var body: some View {
        if isGrid {
            VStack(spacing: 12) {
                ForEach(0..<(itemCount / 2), id: \.self) { _ in
                    HStack(spacing: 12) {
                        SkeletonBlock()
                            .frame(height: 200)

                        SkeletonBlock()
                            .frame(height: 240)
                    }
                }
            }
            .padding(20)
        } else {
            VStack(spacing: 16) {
                ForEach(0..<itemCount, id: \.self) { _ in
                    SkeletonBlock()
                        .frame(height: 100)
                }
            }
            .padding(20)
        }
    }
}

/// Single skeleton block with pulsing animation.
private struct SkeletonBlock: View {
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        NovaPalette.ink.opacity(0.2),
                        NovaPalette.ink.opacity(0.3),
                        NovaPalette.ink.opacity(0.2),
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .shimmering(active: true)
    }
}

/// Modifier that adds a shimmer effect to views.
struct ShimmeringModifier: ViewModifier {
    @State private var isAnimating = false
    let active: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.2),
                        Color.white.opacity(0.0),
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: isAnimating ? 400 : -400)
                .animation(
                    active ? Animation.linear(duration: 2).repeatForever(autoreverses: false) : nil,
                    value: isAnimating
                )
            )
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func shimmering(active: Bool = true) -> some View {
        modifier(ShimmeringModifier(active: active))
    }
}

#Preview {
    LoadingSkeletonView()
}
