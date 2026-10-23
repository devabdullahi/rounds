import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Week bars (each time a month is picked)
 *
 *    0ms   bars grow from the baseline, left to right, 30ms apart (spring)
 * Reduce Motion: bars at full height.
 * ───────────────────────────────────────────────────────── */

private enum BARS {
    static let stagger = 0.03
    /// Past this many weeks the bars would be slivers, so the chart stops here.
    static let most = 20
    static let low: CGFloat = 10, high: CGFloat = 34, rise: CGFloat = 4
}

/// One bar per week until the exam, rising and then holding: this week in white, the rest lighter.
/// Drawn on the dark green countdown cards (exam month, pace).
struct WeekBars: View {
    let weeks: Int
    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let count = min(weeks, BARS.most)
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(i == 0 ? Theme.accentInk : Theme.accentInk.opacity(0.35))
                    .frame(height: grown || reduceMotion ? min(BARS.high, BARS.low + CGFloat(i) * BARS.rise) : 2)
                    .animation(reduceMotion ? nil : Springs.slide.delay(Double(i) * BARS.stagger), value: grown)
            }
        }
        .frame(height: BARS.high, alignment: .bottom)
        .onAppear { grown = true }
    }
}
