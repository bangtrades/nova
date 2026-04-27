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
        // S13-12 — rewrite `http://localhost:3000/...` asset URLs inline
        // to the configured backend host. The backend's dev-mode asset
        // uploader hardcodes `localhost` into the DB at generation time
        // (assetUploader.ts:98), so on the iPad these URLs resolve to the
        // iPad itself (where nothing's listening). Rewriting on read makes
        // every existing card render without DB migration or asset
        // regeneration. Inlined here (rather than a separate URL extension
        // file) to avoid pbxproj registration churn — the function is
        // single-use and lives where it's called.
        let resolvedURL: URL? = {
            guard let url else { return nil }
            guard let host = url.host?.lowercased(),
                  host == "localhost" || host == "127.0.0.1" || host == "::1"
            else { return url }
            let base = APIHost.baseURL()
            guard let backendHost = base.host else { return url }
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.scheme = base.scheme
            components?.host = backendHost
            components?.port = base.port
            return components?.url ?? url
        }()

        if let resolvedURL {
            AsyncImage(url: resolvedURL) { phase in
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
