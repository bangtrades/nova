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
            .onAppear {
                cachedColumnWidth = (geometry.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
            }
            .onChange(of: geometry.size.width) { _, newWidth in
                cachedColumnWidth = (newWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns)
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
