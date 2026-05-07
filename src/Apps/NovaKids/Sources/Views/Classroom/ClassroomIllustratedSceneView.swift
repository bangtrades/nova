import SwiftUI
import UIKit

/// Image-backed 2.5D classroom scene.
///
/// Renders a full-bleed illustrated classroom artwork asset and
/// overlays normalized tappable hotspots on top. The artwork itself
/// carries the chalkboard / bookshelf / desk / trophy shelf furniture;
/// hotspots only show small affordance markers (a tap sticker on
/// highlighted objects, a count badge on the trophy shelf, a "Soon"
/// badge on disabled objects) so the scene reads as one immersive
/// classroom view from the kid's seat at the desk.
///
/// Asset names follow `classroom_home_<ageBand>_<orientation>` —
/// e.g. `classroom_home_45_landscape`, `classroom_home_45_portrait`.
/// When the matching asset is missing, the view gracefully falls back
/// to the SwiftUI-drawn `ClassroomBackgroundView` so the app still
/// builds and runs before the final art lands.
public struct ClassroomIllustratedSceneView: View {
    let model: ClassroomSceneModel
    let assetResolver: ClassroomSceneAssetResolver
    let onSelect: (ClassroomDestination) -> Void

    public init(
        model: ClassroomSceneModel,
        assetResolver: ClassroomSceneAssetResolver = .default,
        onSelect: @escaping (ClassroomDestination) -> Void
    ) {
        self.model = model
        self.assetResolver = assetResolver
        self.onSelect = onSelect
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let isPortrait = size.height >= size.width

            ZStack(alignment: .topLeading) {
                backgroundLayer(isPortrait: isPortrait, size: size)

                ForEach(model.objects) { object in
                    let objectFrame = frame(for: object, in: size)
                    ClassroomHotspotButton(object: object) {
                        onSelect(object.destination)
                    }
                    .frame(
                        width: objectFrame.width,
                        height: objectFrame.height
                    )
                    .position(
                        x: objectFrame.midX,
                        y: objectFrame.midY
                    )
                    .zIndex(Double(object.frame.maxY * 100))
                }

                if let prompt = model.activePrompt {
                    ClassroomDashyGuideLayer(prompt: prompt)
                        .frame(maxWidth: min(size.width * 0.66, 560))
                        .position(x: size.width * 0.54, y: max(88, size.height * 0.095))
                        .zIndex(200)
                }

                // Dev-only hotspot alignment overlay. Returns EmptyView when
                // the NOVA_CLASSROOM_HOTSPOTS_DEBUG flag is unset, so it has
                // zero impact on production scenes.
                ClassroomHotspotDebugOverlay(model: model, size: size)
                    .zIndex(300)

                // Dev-only asset readiness HUD. Returns EmptyView when the
                // NOVA_CLASSROOM_ASSET_DEBUG flag is unset. Reports the
                // asset name, UIImage(named:) resolution, image point size,
                // and the hasProductionAsset(...) gate result so engineers
                // can confirm which render path is live and why.
                ClassroomAssetDebugHUD(
                    model: model,
                    size: size,
                    renderPath: .illustrated,
                    assetResolver: assetResolver
                )
                .zIndex(310)
            }
        }
        .background(NovaPalette.novaBackground)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func backgroundLayer(isPortrait: Bool, size: CGSize) -> some View {
        let assetName = assetResolver.assetName(for: model.ageBand, isPortrait: isPortrait)
        if let uiImage = UIImage(named: assetName) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()
                .accessibilityHidden(true)
        } else {
            ClassroomBackgroundView()
                .frame(width: size.width, height: size.height)
        }
    }

    private func frame(for object: ClassroomObject, in size: CGSize) -> CGRect {
        let width = max(88, object.frame.width * size.width)
        let height = max(88, object.frame.height * size.height)
        let x = object.frame.minX * size.width
        let y = object.frame.minY * size.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

/// Resolves classroom-scene artwork asset names. The naming
/// convention is `classroom_home_<ageBand>_<orientation>` so future
/// age-band variants (`classroom_home_67_landscape`,
/// `classroom_home_8plus_portrait`, ...) can drop in without
/// touching call sites.
public struct ClassroomSceneAssetResolver {
    public init() {}

    public func assetName(for ageBand: ClassroomAgeBand, isPortrait: Bool) -> String {
        let ageSuffix: String
        switch ageBand {
        case .classroom45:
            ageSuffix = "45"
        case .makerLab67:
            ageSuffix = "67"
        case .aiStudio8Plus:
            ageSuffix = "8plus"
        }
        let orientationSuffix = isPortrait ? "portrait" : "landscape"
        return "classroom_home_\(ageSuffix)_\(orientationSuffix)"
    }

    /// True when at least one orientation asset exists in the bundle
    /// for the given age band. Useful for diagnostics and asset-catalog
    /// verification; production routing uses `hasProductionAsset` so
    /// placeholder imagesets do not replace the richer SwiftUI fallback.
    public func hasAnyAsset(for ageBand: ClassroomAgeBand) -> Bool {
        let portrait = assetName(for: ageBand, isPortrait: true)
        let landscape = assetName(for: ageBand, isPortrait: false)
        return UIImage(named: portrait) != nil || UIImage(named: landscape) != nil
    }

    /// True when the exact current-orientation asset exists. The
    /// scene router uses this check so a landscape-only art drop does
    /// not accidentally render transparent hotspots over the SwiftUI
    /// fallback background in portrait.
    public func hasAsset(for ageBand: ClassroomAgeBand, isPortrait: Bool) -> Bool {
        UIImage(named: assetName(for: ageBand, isPortrait: isPortrait)) != nil
    }

    /// True when the exact current-orientation asset looks like final
    /// classroom artwork rather than the tiny solid-color placeholder
    /// imagesets used to keep the asset catalog buildable.
    ///
    /// The 4-5 contract targets at least 2048 px on the short side at
    /// @2x/@3x input. `UIImage.size` reports points after scale, so final
    /// iPad assets should still be comfortably above this threshold while
    /// the 256x192 / 192x256 placeholders stay below it.
    public func hasProductionAsset(for ageBand: ClassroomAgeBand, isPortrait: Bool) -> Bool {
        guard let image = UIImage(named: assetName(for: ageBand, isPortrait: isPortrait)) else {
            return false
        }

        let shortestSide = min(image.size.width, image.size.height)
        return shortestSide >= 700
    }

    public static let `default` = ClassroomSceneAssetResolver()
}

/// Minimal hotspot button for the illustrated scene. Renders a
/// transparent tap target with a few small badges — no large
/// floating furniture cards. The artwork carries the visible
/// classroom; hotspots only confirm "this is tappable".
private struct ClassroomHotspotButton: View {
    let object: ClassroomObject
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false
    @State private var haloPulse = false

    var body: some View {
        Button {
            guard object.state != .disabled else { return }
            NovaHaptics.tap()
            action()
        } label: {
            decorations
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(minWidth: 88, minHeight: 88)
        .scaleEffect(isPressed && reduceMotion == false ? 0.96 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.72), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(object.accessibilityLabel)
        .accessibilityValue(accessibilityStateValue)
        .accessibilityHint(object.accessibilityHint)
        .accessibilityAddTraits(object.state == .disabled ? [] : .isButton)
        .onAppear {
            // Kick the highlight halo into its repeating breathe cycle.
            // Reduce Motion holds it on its calmer end-state via the
            // animation gate inside `highlightHalo`.
            haloPulse = true
        }
    }

    private var decorations: some View {
        ZStack {
            // Highlighted objects get a soft sun-tinted halo centered
            // inside the hotspot — small, local, and *magical*-feeling
            // rather than a rectangular debug-style outline. The
            // illustrated artwork now carries the visual environment;
            // hotspots only whisper "tap me" via the halo + sticker.
            // Available + disabled hotspots stay fully transparent so
            // the artwork keeps speaking for itself.
            if object.state == .highlighted {
                highlightHalo
            }

            VStack {
                HStack {
                    Spacer()
                    badge
                }
                Spacer()
            }
            .padding(Spacing.xs)
            .allowsHitTesting(false)
        }
    }

    /// A localized radial glow rendered inside the highlighted hotspot.
    /// At idle pulse it expands ~8% and fades up by ~25% opacity, then
    /// settles back — soft enough to read as "this is glowing", not
    /// "this is a button outline". Under Reduce Motion the halo is
    /// rendered statically with no looping animation; the spring
    /// `.animation(...)` is also gated so SwiftUI does not schedule
    /// the breathe cycle at all.
    private var highlightHalo: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        NovaPalette.classroomSun.opacity(0.55),
                        NovaPalette.classroomSun.opacity(0.0),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 90
                )
            )
            .frame(width: 180, height: 180)
            .scaleEffect(reduceMotion ? 1.0 : (haloPulse ? 1.08 : 0.94))
            .opacity(reduceMotion ? 0.55 : (haloPulse ? 0.70 : 0.40))
            .animation(
                reduceMotion
                    ? nil
                    : .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                value: haloPulse
            )
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var badge: some View {
        switch object.state {
        case .highlighted:
            tapSticker
        case .disabled:
            soonBadge
        case .available:
            if object.role == .trophyShelf, let text = object.badgeText {
                countBadge(text: text)
            }
        }
    }

    private var tapSticker: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.caption2.weight(.bold))
                .accessibilityHidden(true)
            Text("Tap")
                .font(NovaPalette.captionFont().weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(NovaPalette.classroomInk)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule(style: .continuous)
                .fill(NovaPalette.classroomSun)
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(NovaPalette.classroomInk, lineWidth: 1.5)
        }
        .shadow(color: NovaPalette.classroomInk.opacity(0.18), radius: 2, y: 1)
        .accessibilityHidden(true)
    }

    private func countBadge(text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.caption2.weight(.bold))
                .accessibilityHidden(true)
            Text(text)
                .font(NovaPalette.captionFont().weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(NovaPalette.classroomInk)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule(style: .continuous)
                .fill(NovaPalette.classroomSun)
        )
        .overlay {
            Capsule(style: .continuous)
                .stroke(NovaPalette.classroomInk, lineWidth: 1.5)
        }
        .shadow(color: NovaPalette.classroomInk.opacity(0.18), radius: 2, y: 1)
        .accessibilityHidden(true)
    }

    private var soonBadge: some View {
        Text("Soon")
            .font(NovaPalette.captionFont().weight(.bold))
            .foregroundStyle(NovaPalette.classroomInk)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule(style: .continuous)
                    .fill(NovaPalette.classroomPaper.opacity(0.92))
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.75), lineWidth: 1.5)
            }
            .accessibilityHidden(true)
    }

    private var accessibilityStateValue: String {
        switch object.state {
        case .available:
            return ""
        case .highlighted:
            return "Ready to tap"
        case .disabled:
            return "Coming soon"
        }
    }
}

#Preview {
    ClassroomIllustratedSceneView(model: .home(currentLessonId: UUID())) { _ in }
        .environmentObject(NavigationNarrator(voiceManager: nil))
}
