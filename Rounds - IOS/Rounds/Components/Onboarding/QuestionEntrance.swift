import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Onboarding question (on arrival)
 *
 *    0ms   icon badge and question fade up, y 8 → 0
 *  120ms   first answer row fades up, y 14 → 0 (spring)
 *   +50ms  each following row, in order
 *
 * Tap: the row springs, the check pops in, a light selection haptic.
 * Reduce Motion: everything in place at once, fades only.
 * ───────────────────────────────────────────────────────── */

enum QUESTION {
    static let rowStart = 0.12   // s before the first row
    static let rowGap = 0.05     // s between rows
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.8)
}

extension EnvironmentValues {
    /// Whether the onboarding question around this view has arrived on screen, so its rows animate in.
    @Entry var questionShown = true
}

/// Fades a question's part up into place once the question is on screen, `order` steps after the first.
struct QuestionEntrance: ViewModifier {
    let order: Int
    var lift: CGFloat = 14
    var start = QUESTION.rowStart
    @Environment(\.questionShown) private var shown
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : lift)
            .animation(reduceMotion ? .easeOut(duration: 0.2) : QUESTION.spring.delay(start + Double(order) * QUESTION.rowGap), value: shown)
    }
}
