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

/// Chevron that rotates with its disclosure.
struct DisclosureChevron: View {
    let open: Bool
    var body: some View {
        AppIcon(.chevronDown, size: 18)
            .foregroundStyle(Theme.muted)
            .rotationEffect(.degrees(open ? DISCLOSURE.chevronOpen : 0))
            .animation(DISCLOSURE.open, value: open)
    }
}

/// Small sentence-case label for fields and in-card sections. All-caps `Eyebrow` is reserved for
/// true section headers outside cards, so labels don't all shout at the same volume.
struct FieldLabel: View {
    let text: String
    var color: Color = Theme.muted
    init(_ text: String, color: Color = Theme.muted) { self.text = text; self.color = color }
    var body: some View {
        Text(text).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
    }
}

/// One missed red flag and why it matters. Same row on Patients and Debrief.
struct MissItem: View {
    let miss: Miss
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(Theme.warn).frame(width: 6, height: 6).padding(.top, 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(miss.flag).font(.system(size: 15, weight: .semibold))
                Text(miss.why).font(.system(size: 14)).foregroundStyle(Theme.muted).lineSpacing(2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
