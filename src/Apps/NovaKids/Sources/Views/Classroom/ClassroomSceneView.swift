import SwiftUI

public struct ClassroomSceneView: View {
    let model: ClassroomSceneModel
    let onSelect: (ClassroomDestination) -> Void

    public init(
        model: ClassroomSceneModel,
        onSelect: @escaping (ClassroomDestination) -> Void
    ) {
        self.model = model
        self.onSelect = onSelect
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack(alignment: .topLeading) {
                ClassroomBackgroundView()

                ForEach(model.objects) { object in
                    ClassroomObjectButton(object: object) {
                        onSelect(object.destination)
                    }
                    .frame(
                        width: frame(for: object, in: size).width,
                        height: frame(for: object, in: size).height
                    )
                    .position(
                        x: frame(for: object, in: size).midX,
                        y: frame(for: object, in: size).midY
                    )
                }

                if let prompt = model.activePrompt {
                    ClassroomDashyGuideLayer(prompt: prompt)
                        .frame(maxWidth: min(size.width * 0.66, 560))
                        .position(x: size.width * 0.55, y: max(104, size.height * 0.11))
                }
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
