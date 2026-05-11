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
/// - The HUD is compiled as a no-op in Release. In Debug builds, the
///   classroom rows remain non-production QA tooling and the art-slot
///   sections can receive scroll gestures when the asset tables exceed
///   the viewport.
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
        #if DEBUG
        ProcessInfo.processInfo.environment["NOVA_CLASSROOM_ASSET_DEBUG"] == "1"
        #else
        false
        #endif
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

        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
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

                Divider()
                    .overlay(Color.white.opacity(0.2))

                LessonArtSlotReadinessPanel()

                Divider()
                    .overlay(Color.white.opacity(0.2))

                RewardArtSlotReadinessPanel()
            }
        }
        .scrollIndicators(.visible)
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(
            maxWidth: min(max(size.width - 24, 320), 1080),
            maxHeight: min(max(size.height - 24, 320), 720),
            alignment: .topLeading
        )
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

private struct LessonArtSlotReadinessPanel: View {
    private var resolvedSlots: Int {
        LessonArtSlot.allCases.filter { $0.resolvedName != nil }.count
    }

    private var missingSlots: Int {
        LessonArtSlot.allCases.count - resolvedSlots
    }

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 255, maximum: 360), spacing: 6, alignment: .topLeading)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("lesson art slots")
                    .foregroundStyle(Color.white.opacity(0.9))
                Text("\(resolvedSlots) ok")
                    .foregroundStyle(.green)
                Text("\(missingSlots) missing")
                    .foregroundStyle(missingSlots == 0 ? .green : .red)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(LessonArtSlot.allCases, id: \.self) { slot in
                    LessonArtSlotReadinessRow(slot: slot)
                }
            }
        }
    }
}

private struct LessonArtSlotReadinessRow: View {
    let slot: LessonArtSlot

    private var resolvedName: String? {
        slot.resolvedName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(resolvedName == nil ? "MISS" : "OK")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(resolvedName == nil ? .white : .black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(statusColor, in: Capsule())

                Text(slot.rawValue)
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Text("candidates: \(slot.candidates.joined(separator: ", "))")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.62))
                .lineLimit(2)
                .truncationMode(.middle)

            Text("resolved: \(resolvedName ?? "missing")")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(resolvedName == nil ? .red : .green)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(statusColor.opacity(resolvedName == nil ? 0.22 : 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(statusColor.opacity(resolvedName == nil ? 0.8 : 0.35), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        resolvedName == nil ? .red : .green
    }
}

private struct RewardArtSlotReadinessPanel: View {
    private var resolvedSlots: Int {
        ClassroomRewardArtSlot.allCases.filter { $0.resolvedName != nil }.count
    }

    private var missingSlots: Int {
        ClassroomRewardArtSlot.allCases.count - resolvedSlots
    }

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 255, maximum: 360), spacing: 6, alignment: .topLeading)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("reward art slots")
                    .foregroundStyle(Color.white.opacity(0.9))
                Text("\(resolvedSlots) ok")
                    .foregroundStyle(.green)
                Text("\(missingSlots) missing")
                    .foregroundStyle(missingSlots == 0 ? .green : .red)
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(ClassroomRewardArtSlot.allCases, id: \.self) { slot in
                    RewardArtSlotReadinessRow(slot: slot)
                }
            }
        }
    }
}

private struct RewardArtSlotReadinessRow: View {
    let slot: ClassroomRewardArtSlot

    private var resolvedName: String? {
        slot.resolvedName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(resolvedName == nil ? "MISS" : "OK")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(resolvedName == nil ? .white : .black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(statusColor, in: Capsule())

                Text(slot.rawValue)
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Text("candidates: \(slot.candidates.joined(separator: ", "))")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.62))
                .lineLimit(2)
                .truncationMode(.middle)

            Text("resolved: \(resolvedName ?? "missing")")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(resolvedName == nil ? .red : .green)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(statusColor.opacity(resolvedName == nil ? 0.22 : 0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(statusColor.opacity(resolvedName == nil ? 0.8 : 0.35), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        resolvedName == nil ? .red : .green
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
