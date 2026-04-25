import SwiftUI

/// 2-column masonry grid layout optimized for iPad.
///
/// Provides staggered grid layout with varied heights, mimicking Pinterest-style
/// content arrangement. Uses GeometryReader for responsive sizing.
public struct MasonryGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let columns: Int
    let spacing: CGFloat
    let content: (Item) -> Content

    @State private var cachedColumnWidth: CGFloat = 0

    public init(
        items: [Item],
        columns: Int = 2,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }

    /// Compute column width from a measured container width. Skips when
    /// the container hasn't been measured yet (width <= 0), and clamps
    /// the result so a viewport narrower than the gutter sum doesn't
    /// produce a negative frame width.
    private func updateColumnWidth(for containerWidth: CGFloat) {
        guard containerWidth > 0 else { return }
        let gutterTotal = spacing * CGFloat(columns - 1)
        let raw = (containerWidth - gutterTotal) / CGFloat(columns)
        cachedColumnWidth = max(0, raw)
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: spacing) {
                ForEach(0..<((items.count + columns - 1) / columns), id: \.self) { rowIndex in
                    HStack(spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { colIndex in
                            let itemIndex = rowIndex * columns + colIndex

                            if itemIndex < items.count {
                                content(items[itemIndex])
                                    .frame(width: cachedColumnWidth)
                            } else {
                                Color.clear
                                    .frame(width: cachedColumnWidth)
                            }
                        }
                    }
                }
                Spacer()
            }
            // S12-12: clamp + skip-on-zero to silence the SwiftUI runtime
            // warning "Invalid frame dimension (negative or non-finite)"
            // that fires every layout pass. Root cause: on the first
            // layout, `geometry.size.width` can be 0 (view not yet
            // measured), and the formula `(0 - spacing * (columns - 1)) /
            // columns` produces a NEGATIVE width — e.g. for spacing=12
            // columns=2 that's (0 - 12) / 2 = -6. SwiftUI clamps to 0
            // internally so the UI still renders, but the warning spams
            // the console on every re-layout (visible in Xcode's debug
            // pane every time you scroll or rotate). Two-step fix:
            // (1) skip the assignment entirely when geometry hasn't
            //     measured yet (size.width == 0) — wait until SwiftUI
            //     gives us a real number;
            // (2) `max(0, raw)` clamp as a defensive belt for any other
            //     edge case (spacing > geometry.width, which would
            //     happen on a viewport narrower than the gutter sum).
            // Both .onAppear and .onChange run through the same helper
            // so the math lives in one place and stays trivially auditable.
            .onAppear { updateColumnWidth(for: geometry.size.width) }
            .onChange(of: geometry.size.width) { _, newWidth in
                updateColumnWidth(for: newWidth)
            }
        }
    }
}

/// Preview showing masonry grid with sample tiles.
#Preview {
    struct SampleItem: Identifiable {
        let id = UUID()
        let text: String
        let height: CGFloat
    }

    let items = [
        SampleItem(text: "Item 1", height: 200),
        SampleItem(text: "Item 2", height: 240),
        SampleItem(text: "Item 3", height: 200),
        SampleItem(text: "Item 4", height: 220),
        SampleItem(text: "Item 5", height: 200),
        SampleItem(text: "Item 6", height: 260),
    ]

    return MasonryGrid(items: items) { item in
        VStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(NovaPalette.novaBlue.opacity(0.3))
                .frame(height: item.height)

            Text(item.text)
                .font(NovaPalette.bodyFont())
                .foregroundStyle(.primary)
        }
    }
    .padding(20)
}
