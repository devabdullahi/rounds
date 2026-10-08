import SwiftUI

/// Hero art placement and pop-in, used by every onboarding hero.
extension View {
    /// Places a hero element by its top-left corner on the 350×400 board.
    func at(_ x: CGFloat, _ y: CGFloat) -> some View { offset(x: x, y: y) }

    /// Hero elements pop in: scale 0.85 → 1 and fade, after `delay`. Reduce Motion shows them at once.
    func heroPop(_ shown: Bool, delay: Double) -> some View { modifier(HeroPop(shown: shown, delay: delay)) }
}

private struct HeroPop: ViewModifier {
    let shown: Bool
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .scaleEffect(shown || reduceMotion ? 1 : 0.85)
            .animation(reduceMotion ? nil : Springs.pop.delay(delay), value: shown)
    }
}
