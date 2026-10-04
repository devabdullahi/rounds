import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Status bar scrim
 *
 * Keeps scrolled content from colliding with the status bar
 * (time, battery), the way Apple's own apps do.
 *
 *   at top      nothing behind the status bar
 *   scrolled    blurred bar fades in behind it, hairline below (200ms)
 *   back to top fades out again (200ms)
 * ───────────────────────────────────────────────────────── */

private enum SCRIM {
    static let threshold: CGFloat = -1      // pt scrolled before the bar appears
    static let fade = Animation.easeOut(duration: 0.2)
    static let space = "scrimScroll"
}

private struct ScrimOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Drop-in replacement for a vertical `ScrollView` on screens without a navigation bar.
struct ScrimScrollView<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var scrolled = false

    var body: some View {
        ScrollView {
            content.background(
                GeometryReader { g in
                    Color.clear.preference(key: ScrimOffsetKey.self,
                                           value: g.frame(in: .named(SCRIM.space)).minY)
                }
            )
        }
        .coordinateSpace(.named(SCRIM.space))
        .onPreferenceChange(ScrimOffsetKey.self) { y in
            let now = y < SCRIM.threshold
            if now != scrolled { withAnimation(SCRIM.fade) { scrolled = now } }
        }
        .overlay(alignment: .top) {
            // A zero-height view whose background extends up into the status bar area.
            Color.clear
                .frame(height: 0)
                .background(.bar, ignoresSafeAreaEdges: .top)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
                .opacity(scrolled ? 1 : 0)
                .allowsHitTesting(false)
        }
    }
}
