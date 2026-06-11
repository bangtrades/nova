import SwiftUI
import UniformTypeIdentifiers
import Combine
import NovaCore
import UIKit

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
        ChalkboardLessonCardSurface(cardKind: .experiment, title: cardTitle) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                instructionsBlock

                dropTargetsBlock

                dragItemsBlock
            }
        }
        .padding(.horizontal, Spacing.md)
        .overlay {
            completionOverlay
        }
        .overlay {
            if showConfetti {
                ConfettiView(isActive: $showConfetti)
                    .allowsHitTesting(false)
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

    // MARK: - Subviews

    private var cardTitle: String {
        if let title = card.content.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           title.isEmpty == false {
            return title
        }

        return "Experiment"
    }

    /// Instructions rendered as a yellow task-card sticky note above the
    /// tabletop activity. Falls back to nothing when the card has no
    /// instructions copy — the surface header pill still labels the activity.
    @ViewBuilder
    private var instructionsBlock: some View {
        if let instructions = card.content.instructions {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "list.bullet.clipboard")
                    .font(.title3)
                    .foregroundStyle(NovaPalette.classroomLeaf)
                    .accessibilityHidden(true)

                Text(instructions)
                    .font(NovaPalette.bodyFont())
                    .foregroundStyle(NovaPalette.classroomInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.md)
            .background(
                NovaPalette.classroomSun.opacity(0.32),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NovaPalette.classroomSun.opacity(0.55), lineWidth: 2)
            )
        }
    }

    /// Drop targets sit on a tabletop activity surface. The painted
    /// asset is resolved through `LessonArtSlot.experimentTabletopLandscape`
    /// (canonical: `lesson_experiment_tabletop_45_landscape`; legacy:
    /// `lesson_experiment_table_45_landscape`); otherwise a paper-
    /// tinted rounded rectangle stands in.
    private var dropTargetsBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Drop here:")
                .font(NovaPalette.smallHeadingFont())
                .foregroundStyle(NovaPalette.classroomInk.opacity(0.7))

            HStack(spacing: Spacing.sm) {
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
        .padding(PaintedArtContentInsets.paintedPanelContent)
        .background(experimentTableBackground)
        .overlay {
            if LessonArtSlot.experimentTabletopLandscape.hasAsset == false {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NovaPalette.classroomInk.opacity(0.18), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var experimentTableBackground: some View {
        if let asset = LessonArtSlot.experimentTabletopLandscape.resolvedName {
            Image(asset)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NovaPalette.classroomPaper.opacity(0.5))
        }
    }

    /// Draggable manipulatives row at the bottom of the tabletop.
    /// Items hide once placed, and bounce back on a wrong drop. The
    /// row sits on a painted material tray
    /// (`LessonArtSlot.experimentMaterialTray`) when the asset has
    /// shipped so the manipulatives read as classroom tabletop
    /// supplies; falls back to a paper-tinted rounded rectangle with
    /// an ink hairline when the asset is missing.
    private var dragItemsBlock: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Drag items:")
                .font(NovaPalette.smallHeadingFont())
                .foregroundStyle(NovaPalette.classroomInk.opacity(0.7))

            HStack(spacing: Spacing.sm) {
                ForEach(dragItems) { item in
                    if item.isPlaced == false {
                        DraggableItemView(item: item)
                            .scaleEffect(
                                bouncingItemId == item.id && showBounceBack ? 0.9 : 1.0
                            )
                    }
                }

                Spacer()
            }
            .frame(height: 80)
        }
        .padding(PaintedArtContentInsets.materialTrayContent)
        .background(materialTrayBackground)
    }

    /// Background for the completion sticker. Prefers the painted
    /// `LessonArtSlot.experimentSuccessCard` sticker so the moment
    /// reads as a classroom reward; falls back to the prior paper
    /// rounded-rectangle fill when the asset has not shipped. Live
    /// text continues to render in SwiftUI on top, so the
    /// completion message remains readable and accessible
    /// regardless of which path renders.
    @ViewBuilder
    private var successCardBackground: some View {
        if let asset = LessonArtSlot.experimentSuccessCard.resolvedName {
            Image(asset)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(NovaPalette.classroomPaper)
        }
    }

    @ViewBuilder
    private var materialTrayBackground: some View {
        if let trayAsset = LessonArtSlot.experimentMaterialTray.resolvedName {
            Image(trayAsset)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NovaPalette.classroomPaper.opacity(0.30))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(NovaPalette.classroomInk.opacity(0.16), lineWidth: 1)
                )
        }
    }

    /// Floating "All set!" celebration card + Next button shown on completion.
    /// Lives in an overlay so it floats above the tabletop without re-laying
    /// out the placed manipulatives.
    ///
    /// When `LessonArtSlot.experimentSuccessCard` has shipped, the
    /// painted sticker / certificate is rendered as the card's
    /// background so the moment reads as a tabletop reward sticker
    /// rather than a generic alert. SwiftUI live text — the star
    /// glyph, `completionMessage`, and "Amazing work!" caption —
    /// continues to render on top of either the painted card or the
    /// SwiftUI paper fallback. The existing `completionOpacity`
    /// scale + opacity drive the entrance, and Reduce Motion is
    /// gated upstream in `celebrateCompletion()` (see the
    /// `withAnimation(reduceMotion ? nil : .default)` there); the
    /// painted asset adds no new motion.
    @ViewBuilder
    private var completionOverlay: some View {
        if showConfetti {
            VStack(spacing: Spacing.lg) {
                Spacer()

                VStack(spacing: Spacing.md) {
                    Image(systemName: "star.fill")
                        .font(.largeTitle)
                        .foregroundStyle(NovaPalette.classroomSun)
                        .accessibilityHidden(true)

                    Text(completionMessage)
                        .font(NovaPalette.headingFont())
                        .foregroundStyle(NovaPalette.classroomInk)
                        .multilineTextAlignment(.center)

                    Text("Amazing work!")
                        .font(NovaPalette.bodyFont())
                        .foregroundStyle(NovaPalette.classroomInk.opacity(0.7))
                }
                .padding(PaintedArtContentInsets.rewardCertificateText)
                .background(successCardBackground)
                .shadow(color: NovaPalette.classroomInk.opacity(0.18), radius: 8, x: 0, y: 4)
                .scaleEffect(completionOpacity)
                .opacity(completionOpacity)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Next →")
                        .font(NovaPalette.largeBodyFont())
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(NovaPalette.classroomLeaf)
                        .foregroundStyle(NovaPalette.classroomInk)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(NovaPalette.classroomInk, lineWidth: 1.5)
                        }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.lg)
        }
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
            shakeAnimation = reduceMotion == false

            // S11-16: wrong-drop bounce-back is ambient motion — the wrong() haptic
            // is the primary try-again cue. Skipping the scale animation under
            // reduce-motion leaves the snap-back visually instant but still audible
            // via haptic + VoiceOver.
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                showBounceBack = true
            }

            bounceBackTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard Task.isCancelled == false else { return }
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
                guard Task.isCancelled == false else { return }
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
            guard Task.isCancelled == false else { return }
            // S11-16: auto-dismiss fade is ambient cleanup, not celebration —
            // gated so reduce-motion users get an instant hide.
            withAnimation(reduceMotion ? nil : .default) {
                completionOpacity = 0
            }
        }
    }
}

/// Draggable manipulative — reads as a classroom material tile
/// sitting on the tabletop. Prefers the painted
/// `LessonArtSlot.experimentDragTile` asset as the silhouette fill
/// when shipped; falls back to the SwiftUI sun-tinted paper fill
/// when not. Either way, the ink stroke, drop shadow, item label,
/// and glyph stay live in SwiftUI on top so the tile reads the
/// same regardless of whether art has landed.
///
/// The painted layer is `accessibilityHidden(true)` and
/// `allowsHitTesting(false)`, which preserves the existing `.draggable`
/// gesture: the recognizer attaches to the outer view, not to the
/// fill, so swapping the fill from a SwiftUI shape to a clipped
/// `Image` does not change drag-and-drop behavior.
private struct DraggableItemView: View {
    let item: ExperimentCardView.DragItemState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            tileBackdrop

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
                        .foregroundStyle(NovaPalette.classroomInk)
                        .accessibilityHidden(true)
                }

                Text(item.label)
                    .font(NovaPalette.smallHeadingFont())
                    .foregroundStyle(NovaPalette.classroomInk)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .padding(8)

            // V2-S4-F3: "pick me up" badge — finger-tap glyph pinned
            // to the tile's top-right corner. Static (no motion),
            // so it doubles as the reduce-motion fallback for the
            // pulse below: a non-reader sees the finger and knows
            // the tile is liftable even with all animation off.
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.caption2)
                        .foregroundStyle(NovaPalette.classroomInk.opacity(0.7))
                        .padding(4)
                        .background(
                            Circle()
                                .fill(NovaPalette.classroomPaper.opacity(0.9))
                                .overlay(
                                    Circle()
                                        .stroke(NovaPalette.classroomInk.opacity(0.35), lineWidth: 0.75)
                                )
                        )
                        .accessibilityHidden(true)
                        .padding(4)
                }
                Spacer()
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NovaPalette.classroomInk, lineWidth: 1.5)
        }
        // V2-S4-F3: deeper lift shadow than the prior 18%/r3 — the
        // tile reads as floating above the material tray, reinforcing
        // "this is pick-up-able". Static, so reduce-motion keeps it.
        .shadow(color: NovaPalette.classroomInk.opacity(0.28), radius: 5, x: 0, y: 3)
        // V2-S4-F3: gentle breathing pulse on idle tiles cues "pick
        // me up" without words. The scale delta is small (1.0 → 1.03)
        // so it doesn't fight the bounce-back scale driven externally
        // via `bouncingItemId`. Gated behind reduce-motion — the
        // static finger-tap badge above is the non-motion fallback,
        // and the deeper lift shadow stays regardless.
        .scaleEffect(pulse && reduceMotion == false ? 1.03 : 1.0)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
            value: pulse
        )
        .onAppear {
            if reduceMotion == false {
                pulse = true
            }
        }
        .draggable(item) {
            // Drag-preview ghost — kept visually consistent with the
            // source tile so the painted manipulative is recognizable
            // mid-drag.
            VStack {
                ZStack {
                    tileBackdrop

                    Text(item.label)
                        .font(NovaPalette.smallHeadingFont())
                        .foregroundStyle(NovaPalette.classroomInk)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(NovaPalette.classroomInk, lineWidth: 1.5)
                }
                .frame(height: 60)
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .accessibilityLabel("Drag item: \(item.label)")
    }

    @ViewBuilder
    private var tileBackdrop: some View {
        if let asset = LessonArtSlot.experimentDragTile.resolvedName {
            Image(asset)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NovaPalette.classroomSun)
        }
    }
}

/// Drop target zone view.
///
/// Layout layering (bottom → top):
///   1. Painted `LessonArtSlot.experimentDropZone` backdrop, when the
///      asset has shipped. Falls through to `EmptyView()` when missing
///      so the rest of the SwiftUI cue stack reads identically.
///   2. Live dashed chalk-outline targeting cue. Always rendered
///      regardless of the painted backdrop so a four-year-old still
///      sees the hover-to-drop affordance, and so the brighten-on-
///      target feedback survives the painted asset.
///   3. Filled-item leaf treatment (when a tile has landed) or the
///      empty `arrow.down.circle` + label cue (when the zone is
///      waiting).
private struct DropTargetView: View {
    let target: ExperimentCardView.DropTargetState
    let dragItems: [ExperimentCardView.DragItemState]
    let onDrop: (ExperimentCardView.DragItemState, ExperimentCardView.DropTargetState) -> Void

    @State private var isTargeted = false
    @State private var idlePulse = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isEmpty: Bool { target.filledWith == nil }

    var body: some View {
        ZStack {
            // Painted tabletop drop-zone art — sits beneath the live
            // SwiftUI targeting outline + the placed/empty cues.
            // Renders only when the lesson art has shipped; falls
            // through to EmptyView so the dashed outline + cue stack
            // continues to read as it always did. The painted layer
            // is decorative — `.allowsHitTesting(false)` and
            // `.accessibilityHidden(true)` keep it out of the drop
            // gesture path and the VoiceOver tree.
            paintedDropZoneBackdrop

            // V2-S4-F3: "put it here" underglow. Soft sky-tinted fill
            // on empty zones that breathes opacity (0.10 → 0.22) under
            // motion, brightens to a solid leaf-tinted fill while a
            // tile is hovering, and clears once the zone has been
            // filled. Reduce-motion path collapses the breathing to a
            // static medium-opacity fill so a non-reader still sees a
            // colored landing pad without animation.
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(underglowColor)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                    value: idlePulse
                )
                .animation(.easeInOut(duration: 0.15), value: isTargeted)

            // Base zone — dashed chalk outline that brightens when a tile
            // is hovering, drawn in classroom palette so it matches the
            // tabletop instead of the previous comic-book novaBlue/novaGreen.
            // Rendered above the painted backdrop on purpose: the
            // targeting cue is load-bearing for drag-and-drop UX and
            // must always be visible.
            // V2-S4-F3: when a tile is in flight over this zone, the
            // stroke thickens (2 → 3.5pt) on top of the color swap so
            // the targeting cue reads at a glance even with the kid's
            // hand obscuring half the card.
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isTargeted ? NovaPalette.classroomLeaf : NovaPalette.classroomSky,
                    style: StrokeStyle(lineWidth: isTargeted ? 3.5 : 2, dash: [8])
                )
                .animation(.easeInOut(duration: 0.15), value: isTargeted)

            if let filledItemId = target.filledWith,
               let filledItem = dragItems.first(where: { $0.id == filledItemId }) {
                // Show placed item — leaf-tinted paper rectangle with a
                // green check, reading as "this tile landed correctly".
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(NovaPalette.titleFont())
                        .foregroundStyle(NovaPalette.classroomLeaf)
                        .accessibilityHidden(true)

                    Text(filledItem.label)
                        .font(NovaPalette.smallHeadingFont())
                        .foregroundStyle(NovaPalette.classroomInk)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .background(
                    NovaPalette.classroomLeaf.opacity(colorScheme == .dark ? 0.18 : 0.14),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(NovaPalette.classroomLeaf.opacity(0.65), lineWidth: 1.5)
                }
            } else {
                VStack(spacing: 8) {
                    // V2-S4-F3: swap to the filled variant + bob the
                    // glyph 4pt downward to reinforce "drop here".
                    // Reduce-motion path holds the arrow still — the
                    // filled-circle glyph itself is the static cue,
                    // unambiguously different from the surrounding
                    // dashed outline.
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(NovaPalette.classroomSky)
                        .offset(y: idlePulse && reduceMotion == false ? 4 : 0)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.95).repeatForever(autoreverses: true),
                            value: idlePulse
                        )
                        .accessibilityHidden(true)

                    Text(target.label)
                        .font(NovaPalette.smallHeadingFont())
                        .foregroundStyle(NovaPalette.classroomInk)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .onAppear {
            if reduceMotion == false {
                idlePulse = true
            }
        }
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

    // V2-S4-F3: derives the underglow fill color from zone state.
    // - Hovering (isTargeted): leaf-tinted, strong, attention-grabbing.
    // - Empty + motion allowed: sky-tinted, breathing via `idlePulse`.
    // - Empty + reduce-motion: sky-tinted static medium opacity, so
    //   the "landing pad" reads without any animation.
    // - Filled: clear — the leaf-tinted placed-item overlay supplies
    //   its own visual confirmation; doubling up would just muddy it.
    private var underglowColor: Color {
        if isEmpty == false {
            return Color.clear
        }
        if isTargeted {
            return NovaPalette.classroomLeaf.opacity(0.28)
        }
        if reduceMotion {
            return NovaPalette.classroomSky.opacity(0.16)
        }
        return NovaPalette.classroomSky.opacity(idlePulse ? 0.22 : 0.10)
    }

    @ViewBuilder
    private var paintedDropZoneBackdrop: some View {
        if let asset = LessonArtSlot.experimentDropZone.resolvedName {
            Image(asset)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
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
                if shakeAnimation {
                    setupTimer()
                }
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
        guard shakeAnimation else {
            subscription = nil
            offset = 0
            return
        }

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
