import SwiftUI

/// A looping clock from 0 to `period` ms. Frozen at 0 with Reduce Motion, or when `paused`
/// (off screen, app in the background). Frame 0 must be a good drawing on its own.
struct LoopClock<Content: View>: View {
    let period: Double
    var paused: Bool
    let content: (Double) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    init(period: Double, paused: Bool = false, @ViewBuilder content: @escaping (Double) -> Content) {
        self.period = period
        self.paused = paused
        self.content = content
    }

    var body: some View {
        let still = paused || reduceMotion
        TimelineView(.animation(minimumInterval: nil, paused: still)) { context in
            let t = still ? 0 : (context.date.timeIntervalSince(start) * 1000).truncatingRemainder(dividingBy: period)
            content(t)
        }
    }
}
