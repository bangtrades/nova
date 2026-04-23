import SwiftUI
import UniformTypeIdentifiers
import Combine
import NovaCore

/// Interactive drag-and-drop experiment card.
///
/// Shows draggable items at bottom and drop target zones at top.
/// Provides haptic feedback, animations, and celebration on completion.
public struct ExperimentCardView: View {
    /// The card to display.
    let card: Card

    @State private var dragItems: [DragItemState] = []
    @State private var dropTargets: [DropTargetState] = []
    @State private var showConfetti = false
    @State private var completionMessage = ""
    @State private var completionOpacity: Double = 0
    @State private var shakeAnimation = false
    @State private var showBounceBack = false
    @State private var bouncingItemId: String?
    @State private var bounceBackTask: Task<Void, Never>?
    @State private var shakeTask: Task<Void, Never>?
    @State private var dismissTask: Task<Void, Never>?

    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorScheme) var colorScheme

    struct DragItemState: Identifiable, Codable, Transferable {
        let id: String
        let label: String
        let imageURL: URL?
        var isPlaced: Bool = false
        var placedOnTargetId: String? = nil

        static var transferRepresentation: some TransferRepresentation {
            CodableRepresentation(contentType: .data)
        }
    }

    struct DropTargetState: Identifiable {
        let id: String
        let label: String
        let acceptsItemIds: [String]
        var filledWith: String? = nil
    }

    public init(card: Card) {
        self.card = card
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    colorScheme == .dark
                        ? NovaPalette.novaGreen.opacity(0.05)
                        : NovaPalette.novaGreen.opacity(0.1),
                    colorScheme == .dark
                        ? NovaPalette.novaBlue.opacity(0.05)
                        : NovaPalette.novaBlue.opacity(0.1),
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    if let title = card.content.title {
                        Text(title)
                            .font(NovaPalette.headingFont())
                            .foregroundStyle(.primary)
                    }

                    if let instructions = card.content.instructions {
                        Text(instructions)
                            .font(NovaPalette.bodyFont())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // Drop targets at top
                VStack(spacing: 12) {
                    Text("Drop here:")
                        .font(NovaPalette.smallHeadingFont())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 12) {
                        ForEach(dropTargets) { target in
                            DropTargetView(
                                target: target,
                                dragItems: dragItems,
                                onDrop: handleDrop(item:onto:)
                            )
                        }
                    }
                    .frame(height: 100)
                }
                .padding(.horizontal, 20)

                Spacer()

                // Draggable items at bottom
                VStack(spacing: 12) {
                    Text("Drag items:")
                        .font(NovaPalette.smallHeadingFont())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 12) {
                        ForEach(dragItems) { item in
                            if !item.isPlaced {
                                DraggableItemView(item: item)
                                    .offset(
                                        x: bouncingItemId == item.id && showBounceBack ? 0 : 0,
                                        y: 0
                                    )
                                    .scaleEffect(bouncingItemId == item.id && showBounceBack ? 0.9 : 1.0)
                            }
                        }

                        Spacer()
                    }
                    .frame(height: 80)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 20)
            }
            .padding(.vertical, 20)

            // Completion message with confetti
            if showConfetti {
                VStack {
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "star.fill")
                            .font(.largeTitle)
                            .foregroundStyle(NovaPalette.novaYellow)
                            .accessibilityHidden(true)

                        Text(completionMessage)
                            .font(NovaPalette.headingFont())
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)

                        Text("Amazing work!")
                            .font(NovaPalette.bodyFont())
                            .foregroundStyle(.secondary)
                    }
                    .padding(24)
                    .background(NovaPalette.novaCardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    .padding(20)
                    .scaleEffect(completionOpacity)
                    .opacity(completionOpacity)

                    Spacer()

                    Button(action: {
                        dismiss()
                    }) {
                        Text("Next →")
                            .font(NovaPalette.largeBodyFont())
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(NovaPalette.novaGreen)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }

            // Confetti particles
            if showConfetti {
                ConfettiView(isActive: $showConfetti)
            }
        }
        .onAppear {
            setupCardData()
        }
        .onDisappear {
            bounceBackTask?.cancel()
            shakeTask?.cancel()
            dismissTask?.cancel()
        }
        .modifier(ShakeModifier(shakeAnimation: shakeAnimation))
    }

    private func setupCardData() {
        // Initialize from card content
        if let items = card.content.dragItems {
            dragItems = items.map { item in
                DragItemState(
                    id: item.id,
                    label: item.label,
                    imageURL: item.imageURL
                )
            }
        }

        if let targets = card.content.dropTargets {
            dropTargets = targets.map { target in
                DropTargetState(
                    id: target.id,
                    label: target.label,
                    acceptsItemIds: target.acceptsItemIds
                )
            }
        }
    }

    private func handleDrop(item: DragItemState, onto target: DropTargetState) {
        // Validate drop
        if target.acceptsItemIds.contains(item.id) {
            // Correct drop
            // S11-16: snap spring reduces to instant state change under reduce-motion —
            // the placement still renders, just without the bounce. Haptic + confetti
            // carry the success cue for users who'd otherwise miss the motion feedback.
            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6)) {
                if let index = dragItems.firstIndex(where: { $0.id == item.id }) {
                    dragItems[index].isPlaced = true
                    dragItems[index].placedOnTargetId = target.id
                }

                if let targetIndex = dropTargets.firstIndex(where: { $0.id == target.id }) {
                    dropTargets[targetIndex].filledWith = item.id
                }
            }

            // S11-15: each correct snap fires commit() (medium), NOT success().
            // Individual snaps are commitments — the user committed a piece;
            // full-completion celebration fires once in celebrateCompletion().
            // Using success() here would stack two VoiceOver "success" cues
            // on the final drop (one per-snap, one full-complete).
            NovaHaptics.commit()

            // Check if all items placed
            if dragItems.allSatisfy({ $0.isPlaced }) {
                celebrateCompletion()
            }
        } else {
            // Wrong drop - bounce back
            bouncingItemId = item.id
            // S11-16: shake-animation driver is skipped entirely under reduce-motion —
            // the ShakeModifier's Timer publisher would otherwise jitter the tile
            // with random ±10pt offsets even without an explicit withAnimation call.
            shakeAnimation = !reduceMotion

            // S11-16: wrong-drop bounce-back is ambient motion — the wrong() haptic
            // is the primary try-again cue. Skipping the scale animation under
            // reduce-motion leaves the snap-back visually instant but still audible
            // via haptic + VoiceOver.
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                showBounceBack = true
            }

            bounceBackTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                    showBounceBack = false
                }
                bouncingItemId = nil
            }

            // S11-15: wrong-drop is a try-again beat, not an acknowledgement.
            // Previous code used .light ("gentle warning") but that's the tap
            // ladder rung — it read as "you did a thing" rather than "not
            // there, try again". Routed through NovaHaptics.wrong() (rigid)
            // for correct semantic mapping.
            NovaHaptics.wrong()

            // Shake animation
            shakeTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                shakeAnimation = false
            }
        }
    }

    private func celebrateCompletion() {
        completionMessage = "All set!"
        showConfetti = true

        // S11-16: celebration fade-in is a one-shot discrete-event per Apple HIG
        // motion-semantics — the user's completion moment should feel special
        // regardless of reduce-motion preference. Confetti + success() haptic +
        // opacity transition all survive the audit as celebration carve-outs.
        withAnimation(.easeInOut(duration: 0.5)) {
            completionOpacity = 1.0
        }

        // S11-15: full-completion celebrate — heavy impact + system success
        // notification so VoiceOver users get the "you did it" cue that
        // sighted users get from the confetti.
        NovaHaptics.success()

        // Auto-dismiss after 2 seconds
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            // S11-16: auto-dismiss fade is ambient cleanup, not celebration —
            // gated so reduce-motion users get an instant hide.
            withAnimation(reduceMotion ? nil : .default) {
                completionOpacity = 0
            }
        }
    }
}

/// Draggable item view.
private struct DraggableItemView: View {
    let item: ExperimentCardView.DragItemState

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            NovaPalette.novaOrange,
                            NovaPalette.novaPink,
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 4) {
                if let imageURL = item.imageURL {
                    LazyImageView(
                        url: imageURL,
                        placeholder: Image(systemName: "photo")
                    )
                    .frame(height: 32)
                } else {
                    Image(systemName: "cube.fill")
                        .font(.title2)
                        .accessibilityHidden(true)
                }

                Text(item.label)
                    .font(NovaPalette.smallHeadingFont())
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(8)
        }
        .draggable(item) {
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(NovaPalette.novaOrange)

                    Text(item.label)
                        .font(NovaPalette.smallHeadingFont())
                        .foregroundStyle(.white)
                }
                .frame(height: 60)
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .accessibilityLabel("Drag item: \(item.label)")
    }
}

/// Drop target zone view.
private struct DropTargetView: View {
    let target: ExperimentCardView.DropTargetState
    let dragItems: [ExperimentCardView.DragItemState]
    let onDrop: (ExperimentCardView.DragItemState, ExperimentCardView.DropTargetState) -> Void

    @State private var isTargeted = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Base zone
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .foregroundStyle(isTargeted ? NovaPalette.novaGreen : NovaPalette.novaBlue)

            if let filledItemId = target.filledWith,
               let filledItem = dragItems.first(where: { $0.id == filledItemId }) {
                // Show placed item
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(NovaPalette.titleFont())
                        .foregroundStyle(NovaPalette.novaGreen)
                        .accessibilityHidden(true)

                    Text(filledItem.label)
                        .font(NovaPalette.smallHeadingFont())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .background(
                    colorScheme == .dark
                        ? NovaPalette.novaGreen.opacity(0.15)
                        : NovaPalette.novaGreen.opacity(0.1)
                )
                .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle")
                        .font(.title2)
                        .foregroundStyle(NovaPalette.novaBlue)
                        .accessibilityHidden(true)

                    Text(target.label)
                        .font(NovaPalette.smallHeadingFont())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .dropDestination(for: ExperimentCardView.DragItemState.self) { items, _ in
            if let item = items.first {
                onDrop(item, target)
                return true
            }
            return false
        } isTargeted: { isTargeted in
            self.isTargeted = isTargeted
        }
        .accessibilityLabel("Drop zone: \(target.label)")
    }
}

/// Shake modifier for wrong drops.
private struct ShakeModifier: ViewModifier {
    let shakeAnimation: Bool
    @State private var offset: CGFloat = 0
    @State private var subscription: AnyCancellable?

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onAppear {
                setupTimer()
            }
            .onDisappear {
                subscription?.cancel()
                subscription = nil
            }
            .onChange(of: shakeAnimation) { oldValue, newValue in
                if newValue {
                    setupTimer()
                } else {
                    subscription?.cancel()
                    subscription = nil
                    offset = 0
                }
            }
    }

    private func setupTimer() {
        subscription?.cancel()
        subscription = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if shakeAnimation {
                    offset = CGFloat.random(in: -10...10)
                } else {
                    offset = 0
                }
            }
    }
}

#Preview {
    let card = Card(
        id: UUID(),
        lessonId: UUID(),
        type: .experiment,
        sortOrder: 0,
        content: Card.CardContent(
            title: "Sort by Color",
            instructions: "Drag each item to the correct color zone",
            dragItems: [
                Card.DragItem(id: "red", label: "Red Ball"),
                Card.DragItem(id: "blue", label: "Blue Square"),
            ],
            dropTargets: [
                Card.DropTarget(id: "red-zone", label: "Red Zone", acceptsItemIds: ["red"]),
                Card.DropTarget(id: "blue-zone", label: "Blue Zone", acceptsItemIds: ["blue"]),
            ]
        )
    )

    return ExperimentCardView(card: card)
}
