import Foundation
import SwiftUI
import UIKit

/// Developer-only asset readiness HUD for the classroom scene.
///
/// **This is QA tooling, not product UI.** It exists so an engineer can
/// verify, on-device, whether the running NovaKids build is rendering
/// the immersive 2.5D illustrated scene or the SwiftUI shape fallback,
/// and *why* — which asset name was looked up, whether
/// `UIImage(named:)` resolved, the resolved image's point size, and
/// whether `ClassroomSceneAssetResolver.hasProductionAsset(...)` passes
/// the production gate (currently a 700pt short-side threshold).
///
/// ## Behavior
///
/// - When the environment variable `NOVA_CLASSROOM_ASSET_DEBUG=1` is
///   present in the running process (set via the Xcode scheme's "Run >
///   Arguments > Environment Variables" pane, or via
///   `xcrun simctl spawn ... env NOVA_CLASSROOM_ASSET_DEBUG=1 ...`),
///   the HUD paints a small translucent panel in the top-leading
///   corner of the scene with the diagnostic readout.
/// - When the variable is absent (the default for every regular
///   install), the view returns `EmptyView()` and contributes
///   nothing — no extra layers, no allocations beyond a single
///   `ProcessInfo` lookup, no draw calls, no accessibility nodes.
///
/// ## Non-goals
///
/// - The HUD does **not** intercept taps. `allowsHitTesting(false)` is
///   set on every visual it draws so the real `ClassroomHotspotButton`
///   underneath still receives touches.
/// - The HUD does **not** alter accessibility for a real user. The
///   whole panel is `accessibilityHidden(true)`.
/// - The HUD does **not** ship enabled. There is no in-app toggle; the
///   only way to turn it on is the environment variable.
///
/// ## Usage
///
/// Both `ClassroomSceneView.shapeFallbackScene` and
/// `ClassroomIllustratedSceneView.body` host this overlay at a high
/// `zIndex` so it floats above the artwork, the hotspots, and the
/// hotspot debug overlay. Each render path passes its own
/// `RenderPath` value so the HUD can call out which path is active.
public struct ClassroomAssetDebugHUD: View {
    public enum RenderPath: String {
        case illustrated
        case fallback
    }

    private let model: ClassroomSceneModel
    private let size: CGSize
    private let renderPath: RenderPath
    private let assetResolver: ClassroomSceneAssetResolver

    public init(
        model: ClassroomSceneModel,
        size: CGSize,
        renderPath: RenderPath,
        assetResolver: ClassroomSceneAssetResolver = .default
    ) {
        self.model = model
        self.size = size
        self.renderPath = renderPath
        self.assetResolver = assetResolver
    }

    /// Read once per init from the process environment. Intentionally
    /// not a `@State` or `@AppStorage` — this is a developer toggle,
    /// not a user preference, and SwiftUI should never observe it.
    public static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["NOVA_CLASSROOM_ASSET_DEBUG"] == "1"
    }

    public var body: some View {
        if Self.isEnabled {
            enabledHUD
        } else {
            // Production path: contribute nothing. SwiftUI elides this
            // branch out of the layout tree entirely.
            EmptyView()
        }
    }

    private var enabledHUD: some View {
        let isPortrait = size.height >= size.width
        let assetName = assetResolver.assetName(for: model.ageBand, isPortrait: isPortrait)
        let resolvedImage = UIImage(named: assetName)
        let isProductionReady = assetResolver.hasProductionAsset(
            for: model.ageBand,
            isPortrait: isPortrait
        )

        return VStack(alignment: .leading, spacing: 4) {
            row(label: "render", value: renderPath.rawValue, color: renderPathColor)
            row(
                label: "ageBand",
                value: ageBandString,
                color: ClassroomAgeBand.isDeveloperOverrideActive ? .orange : .white
            )
            row(label: "orientation", value: isPortrait ? "portrait" : "landscape")
            row(label: "asset", value: assetName, monospaced: true)
            row(
                label: "UIImage(named:)",
                value: resolvedImage == nil ? "nil" : "ok",
                color: resolvedImage == nil ? .red : .green
            )
            row(
                label: "size",
                value: imageSizeString(resolvedImage),
                monospaced: true
            )
            row(
                label: "production",
                value: isProductionReady ? "pass" : "fail",
                color: isProductionReady ? .green : .yellow
            )
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.32), lineWidth: 1)
        )
        .padding(.leading, 12)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var renderPathColor: Color {
        switch renderPath {
        case .illustrated:
            return .green
        case .fallback:
            return .yellow
        }
    }

    private var ageBandString: String {
        let base: String
        switch model.ageBand {
        case .classroom45:
            base = "classroom45"
        case .makerLab67:
            base = "makerLab67"
        case .aiStudio8Plus:
            base = "aiStudio8Plus"
        }
        return ClassroomAgeBand.isDeveloperOverrideActive ? "\(base) (forced)" : base
    }

    private func imageSizeString(_ image: UIImage?) -> String {
        guard let image else { return "—" }
        let w = Int(image.size.width.rounded())
        let h = Int(image.size.height.rounded())
        return "\(w)×\(h) pt"
    }

    private func row(
        label: String,
        value: String,
        color: Color = .white,
        monospaced: Bool = false
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .foregroundStyle(Color.white.opacity(0.6))
            Text(value)
                .foregroundStyle(color)
                .lineLimit(1)
                .truncationMode(.middle)
                .if(monospaced) { view in
                    view.font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
        }
    }
}

private extension View {
    @ViewBuilder
    func `if`<Result: View>(
        _ condition: Bool,
        transform: (Self) -> Result
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
