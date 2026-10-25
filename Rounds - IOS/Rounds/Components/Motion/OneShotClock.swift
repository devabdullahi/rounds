import SwiftUI

/// A clock that plays ONCE from 0 to `duration` ms when `play` turns true, then holds at the end
/// (a scene that tells an action, a chart drawing itself on). With Reduce Motion it shows the end
/// straight away: the final frame carries the meaning, so it must read on its own.
struct OneShotClock<Content: View>: View {
    let duration: Double
    let play: Bool
    let content: (Double) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?

    init(duration: Double, play: Bool, @ViewBuilder content: @escaping (Double) -> Content) {
        self.duration = duration
        self.play = play
        self.content = content
    }

    var body: some View {
        Group {
            if !play {
                content(0)
            } else if reduceMotion {
                content(duration)
            } else {
                TimelineView(.animation(minimumInterval: nil, paused: isDone)) { context in
                    let elapsed = startedAt.map { context.date.timeIntervalSince($0) * 1000 } ?? 0
                    content(min(duration, elapsed))
                }
            }
        }
        .onChange(of: play, initial: true) { _, now in
            startedAt = now ? Date() : nil
        }
    }

    private var isDone: Bool {
        guard let startedAt else { return false }
        return Date().timeIntervalSince(startedAt) * 1000 >= duration
    }
}
