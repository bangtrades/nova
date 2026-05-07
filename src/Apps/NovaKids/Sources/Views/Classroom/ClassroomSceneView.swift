import SwiftUI

/// Top-level classroom scene view.
///
/// Routes between two render paths:
///
/// 1. The new image-backed 2.5D path (`ClassroomIllustratedSceneView`)
///    when an illustrated classroom artwork asset is available in the
///    bundle for the model's age band. Hotspots overlay the artwork
///    with small tap-stickers, count badges, and "Soon" badges.
/// 2. A SwiftUI-only shape-and-furniture fallback when no artwork is
///    present yet — preserves today's behavior so the app keeps
///    building and running before final art lands.
///
/// The `ClassroomSceneModel.objects` hotspot model and route behavior
/// are identical across both paths.
public struct ClassroomSceneView: View {
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
            let isPortrait = proxy.size.height >= proxy.size.width

            if assetResolver.hasProductionAsset(for: model.ageBand, isPortrait: isPortrait) {
                ClassroomIllustratedSceneView(
                    model: model,
                    assetResolver: assetResolver,
                    onSelect: onSelect
                )
            } else {
                shapeFallbackScene
            }
        }
    }

    /// Legacy SwiftUI-drawn scene with full furniture buttons. Used
    /// as the graceful fallback while illustrated artwork is being
    /// produced and imported.
    private var shapeFallbackScene: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack(alignment: .topLeading) {
                ClassroomBackgroundView()

                ForEach(model.objects) { object in
                    let objectFrame = frame(for: object, in: size)
                    ClassroomObjectButton(object: object) {
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

                // Dev-only hotspot alignment overlay (no-op when the
                // NOVA_CLASSROOM_HOTSPOTS_DEBUG flag is unset). Mirrored
                // here in the SwiftUI fallback so a designer can verify
                // hotspot rects without first having to drop final art
                // into the bundle.
                ClassroomHotspotDebugOverlay(model: model, size: size)
                    .zIndex(300)

                // Dev-only asset readiness HUD. Mirrored here so the
                // engineer also sees the "render: fallback" diagnostic
                // when they boot a build without final art — the HUD's
                // job is to *prove* this branch was taken and explain
                // why hasProductionAsset(...) failed.
                ClassroomAssetDebugHUD(
                    model: model,
                    size: size,
                    renderPath: .fallback,
                    assetResolver: assetResolver
                )
                .zIndex(310)
            }
        }
        .background(NovaPalette.novaBackground)
        .accessibilityElement(children: .contain)
    }

    private func frame(for object: ClassroomObject, in size: CGSize) -> CGRect {
        let width = max(88, object.frame.width * size.width)
        let height = max(88, object.frame.height * size.height)
        let x = object.frame.minX * size.width
        let y = object.frame.minY * size.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

#Preview {
    ClassroomSceneView(model: .home(currentLessonId: UUID())) { _ in }
        .environmentObject(NavigationNarrator(voiceManager: nil))
}
