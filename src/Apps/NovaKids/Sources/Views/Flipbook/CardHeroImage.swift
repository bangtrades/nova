import SwiftUI
import NovaCore

/// S13 — comic-book panel hero image for flipbook cards.
///
/// Renders `card.imageURL` as a full-bleed scaled-to-fill image clipped
/// to the parent's shape. Falls back to a caller-provided gradient +
/// icon placeholder when:
///   - `imageURL` is nil (lesson seeded before asset pipeline ran, or
///     OPENAI_API_KEY wasn't configured)
///   - `imageURL` exists but the network fetch fails
///   - The image is loading (shows progress spinner over the placeholder
///     so the kid sees motion instead of a blank panel)
///
/// AsyncImage handles the URL fetch + retry behavior internally. The
/// placeholder closure is a `@ViewBuilder` so callers can pass their
/// existing gradient + SF Symbol setup unchanged.
///
/// Usage:
/// ```swift
/// CardHeroImage(url: card.imageURL) {
///     LinearGradient(...) // existing placeholder
///     Image(systemName: "book.circle.fill")
/// }
/// .frame(maxHeight: .infinity)
/// .clipShape(RoundedRectangle(cornerRadius: 16))
/// ```
public struct CardHeroImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let placeholder: () -> Placeholder

    public init(
        url: URL?,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.placeholder = placeholder
    }

    public var body: some View {
        if let url {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    // Show placeholder beneath a small progress indicator
                    // so kids see immediate visual feedback while the
                    // image fetches over LAN/wifi.
                    ZStack {
                        placeholder()
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.4)
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholder()
                @unknown default:
                    placeholder()
                }
            }
        } else {
            placeholder()
        }
    }
}
