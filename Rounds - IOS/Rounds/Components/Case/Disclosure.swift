import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Disclosure ("What you missed")
 *
 * Shared by Patients revisit rows and the Debrief misses row,
 * so every expand in the app moves the same way.
 *
 * OPEN
 *    0ms   row height springs open, chevron 0° → 180°
 *   60ms   section label fades in
 *  110ms   first item slides down 6pt → 0 and fades in
 *  +50ms   each following item (staggered 50ms, chained)
 *  last    action button rises with the final item
 *
 * CLOSE
 *    0ms   everything fades together in 120ms (no stagger:
 *          exits are fast so the row never feels sticky)
 * ───────────────────────────────────────────────────────── */

enum DISCLOSURE {
    static let open = Animation.spring(response: 0.38, dampingFraction: 0.86)   // row height + chevron
    static let itemSpring = Animation.spring(response: 0.34, dampingFraction: 0.88)
    static let firstDelay = 0.06      // s before the label appears
    static let stagger = 0.05         // s between items
    static let offsetY: CGFloat = -6  // items drop in from just above
    static let close = Animation.easeOut(duration: 0.12)
    static let chevronOpen: Double = 180
}

extension View {
    /// Item `index` inside an open disclosure: staggered in, all out together.
    func disclosureItem(_ index: Int) -> some View {
        transition(
            .asymmetric(
                insertion: .opacity.combined(with: .offset(y: DISCLOSURE.offsetY))
                    .animation(DISCLOSURE.itemSpring.delay(DISCLOSURE.firstDelay + Double(index) * DISCLOSURE.stagger)),
                removal: .opacity.animation(DISCLOSURE.close)
            )
        )
    }
}
