import SwiftUI

/* ANIMATION STORYBOARD · Swipe to delete (as in Mail)
 *    drag    row follows the finger, either way; red Delete shows on the side it uncovers
 *    release past ACTION.width/2 → row rests open on Delete; less → springs shut
 *    release past FULL of the row, or a fling → row carries on off that side at the finger's
 *            speed (critically damped spring seeded with the release velocity)
 *    then    onDelete; the caller removes the row inside withAnimation and the red strip
 *            collapses from the bottom (`.collapse`) while the rows below slide up
 *    other row opens / tap on the row → springs shut
 * Reduce Motion: no velocity spring; the row fades out instead of collapsing. */

/// Swipe a row left or right to reveal Delete, or most of the way to delete at once. List's
/// swipeActions only work inside a List; these rows live in a ScrollView.
///
/// `openRow` names the row being swiped or resting open, and stays set a moment after a swipe
/// ends: the row's own button sees the finger lift too, so callers treat a tap on that row as
/// nothing while it's set, instead of opening it.
struct SwipeToDelete: ViewModifier {
    let id: String
    @Binding var openRow: String?
    var enabled = true
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var width: CGFloat = 0
    @State private var dragging = false
    /// Where the row sat when the drag began (0, or open on Delete either side).
    @State private var dragStart: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum ACTION {
        static let width: CGFloat = 88
        /// Share of the row past which letting go deletes without a tap.
        static let full: CGFloat = 0.6
        /// Horizontal travel before the row takes the drag from the scroll view.
        static let start: CGFloat = 14
        /// How long a finished swipe keeps swallowing the row's tap.
        static let settle: Duration = .milliseconds(350)
    }

    private var spring: Animation { reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.32, dampingFraction: 0.86) }
    private var pastFull: Bool { width > 0 && abs(offset) > width * ACTION.full }
    /// The row moved right, so Delete shows on the leading side.
    private var fromLeading: Bool { offset >= 0 }

    func body(content: Content) -> some View {
        ZStack(alignment: fromLeading ? .leading : .trailing) {
            Button { delete(velocity: 0) } label: {
                // The label sits by the uncovered edge, then rides the row's edge past the
                // full-swipe point, as in Mail.
                ZStack(alignment: fromLeading == pastFull ? .trailing : .leading) {
                    Theme.wrong
                    VStack(spacing: 4) {
                        AppIcon(.trash, size: 20)
                        Text("Delete").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: ACTION.width)
                }
                .frame(width: abs(offset))
                .frame(maxHeight: .infinity)
                .clipped()
                .animation(spring, value: pastFull)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)   // the row's own Delete action covers VoiceOver

            content
                .background(Theme.surface)
                .offset(x: offset)
                // While open, a tap on the row closes it.
                .overlay {
                    if offset != 0 && !dragging {
                        Color.clear.contentShape(Rectangle()).onTapGesture { close() }
                    }
                }
        }
        .clipped()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .simultaneousGesture(drag, including: enabled ? .all : .subviews)
        .sensoryFeedback(.impact(weight: .medium), trigger: pastFull) { _, now in now }
        .onChange(of: openRow) { _, now in if now != id && offset != 0 { close() } }
        .onChange(of: enabled) { _, on in if !on { close() } }
        .onAppear { if openRow == id { offset = Self.debugOpenSide * ACTION.width } }
        .accessibilityAction(named: "Delete") { onDelete() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: ACTION.start)
            .onChanged { v in
                // Vertical drags belong to the scroll view.
                guard dragging || abs(v.translation.width) > abs(v.translation.height) * 1.5 else { return }
                if !dragging { dragging = true; dragStart = offset; openRow = id }
                offset = min(width, max(-width, dragStart + v.translation.width))
            }
            .onEnded { v in
                guard dragging else { return }
                dragging = false
                let flung = width > 0 && abs(v.predictedEndTranslation.width) > width
                if pastFull || (flung && (v.predictedEndTranslation.width > 0) == fromLeading) {
                    delete(velocity: v.velocity.width)
                } else if abs(offset) > ACTION.width / 2 {
                    withAnimation(spring) { offset = fromLeading ? ACTION.width : -ACTION.width }
                } else {
                    close()
                }
            }
    }

    private func close() {
        withAnimation(spring) { offset = 0 }
        release()
    }

    /// Slides the row off its open side, keeping the finger's speed, then hands over to the caller.
    private func delete(velocity: CGFloat) {
        let target = (fromLeading ? 1 : -1) * width
        let remaining = max(1, abs(target - offset))
        // Spring velocity is in "fractions of the remaining distance per second".
        let slide: Animation = reduceMotion
            ? .easeOut(duration: 0.2)
            : .interpolatingSpring(mass: 1, stiffness: 320, damping: 36, initialVelocity: abs(velocity) / remaining)
        withAnimation(slide, completionCriteria: .logicallyComplete) {
            offset = target
        } completion: {
            onDelete()
            Task { @MainActor in
                try? await Task.sleep(for: ACTION.settle)
                if openRow == id { openRow = nil }
            }
        }
    }

    /// Clears `openRow` once the lifting finger's tap has passed, unless another row took it.
    private func release() {
        Task { @MainActor in
            try? await Task.sleep(for: ACTION.settle)
            if openRow == id && offset == 0 { openRow = nil }
        }
    }
}

extension SwipeToDelete {
    #if DEBUG
    /// `-screen patients-swipe-left` opens the debug row on the trailing side (-1).
    nonisolated(unsafe) static var debugOpenSide: CGFloat = 1
    #else
    static let debugOpenSide: CGFloat = 1
    #endif
}

/// A deleted row's exit: it shrinks away from the bottom while the rows below move up into its
/// place, instead of vanishing and letting them jump.
struct CollapseTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .mask(alignment: .top) {
                Rectangle().scaleEffect(x: 1, y: phase.isIdentity ? 1 : 0.001, anchor: .top)
            }
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

extension AnyTransition {
    static let collapse = AnyTransition(CollapseTransition())
}

extension View {
    func swipeToDelete(id: String, openRow: Binding<String?>, enabled: Bool = true, onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToDelete(id: id, openRow: openRow, enabled: enabled, onDelete: onDelete))
    }
}
