import SwiftUI

/* ANIMATION STORYBOARD · Swipe to delete
 *    drag    row follows the finger right; red Delete shows behind it
 *    release past ACTION.width/2 → row rests open on Delete; less → springs shut
 *    release past FULL of the row  → row slides off, then onDelete
 *    other row opens / scroll starts / tap on the row → springs shut
 * Reduce Motion: same states, no spring overshoot. */

/// Swipe a row right to reveal Delete, or swipe it most of the way to delete at once. List's
/// swipeActions only work inside a List; these rows live in a ScrollView. One row is open at a
/// time through `openRow`.
struct SwipeToDelete: ViewModifier {
    let id: String
    @Binding var openRow: String?
    var enabled = true
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var width: CGFloat = 0
    @State private var dragging = false
    /// Where the row sat when the drag began (0, or open on Delete).
    @State private var dragStart: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum ACTION {
        static let width: CGFloat = 88
        /// Share of the row past which letting go deletes without a tap.
        static let full: CGFloat = 0.6
        /// Horizontal travel before the row takes the drag from the scroll view.
        static let start: CGFloat = 14
    }

    private var spring: Animation { reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.32, dampingFraction: 0.86) }
    private var pastFull: Bool { width > 0 && offset > width * ACTION.full }

    func body(content: Content) -> some View {
        ZStack(alignment: .leading) {
            Button(action: delete) {
                // Past the full-swipe point the label rides the row's edge, as in Mail.
                ZStack(alignment: pastFull ? .trailing : .leading) {
                    Theme.wrong
                    VStack(spacing: 4) {
                        AppIcon(.trash, size: 20)
                        Text("Delete").font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: ACTION.width)
                }
                .frame(width: max(offset, 0))
                .frame(maxHeight: .infinity)
                .clipped()
                .animation(spring, value: pastFull)
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)   // the row's own Delete action covers VoiceOver

            content
                .background(Theme.surface)
                .offset(x: offset)
                // While open, a tap on the row closes it instead of opening the patient.
                .overlay {
                    if offset > 0 && !dragging {
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
        .onAppear { if openRow == id { offset = ACTION.width } }
        .accessibilityAction(named: "Delete") { onDelete() }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: ACTION.start)
            .onChanged { v in
                // Vertical drags belong to the scroll view.
                guard dragging || abs(v.translation.width) > abs(v.translation.height) * 1.5 else { return }
                if !dragging { dragging = true; dragStart = offset; openRow = id }
                offset = max(0, dragStart + v.translation.width)
            }
            .onEnded { v in
                guard dragging else { return }
                dragging = false
                if pastFull || (width > 0 && v.predictedEndTranslation.width > width) {
                    delete()
                } else if offset > ACTION.width / 2 {
                    withAnimation(spring) { offset = ACTION.width }
                } else {
                    close()
                }
            }
    }

    private func close() {
        withAnimation(spring) { offset = 0 }
        if openRow == id { openRow = nil }
    }

    private func delete() {
        withAnimation(.easeIn(duration: 0.2)) { offset = width }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            openRow = nil
            onDelete()
        }
    }
}

extension View {
    func swipeToDelete(id: String, openRow: Binding<String?>, enabled: Bool = true, onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToDelete(id: id, openRow: openRow, enabled: enabled, onDelete: onDelete))
    }
}
