import SwiftUI

/// One dot per graded case, fourteen to a row (two weeks at one a day): a count the student can
/// see rather than a trend line. Past `mostDots` the grid stops and says how many more. `shown`
/// plays the entrance: rows fill in 50ms apart (ease-out); with Reduce Motion they're simply there.
struct CaseDots: View {
    let count: Int
    var shown = true
    var delay = 0.3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let perRow = 14
    private static let mostDots = 140

    var body: some View {
        let drawn = min(count, Self.mostDots)
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: Self.perRow), spacing: 5) {
                ForEach(0..<drawn, id: \.self) { i in
                    Circle()
                        .fill(Theme.accent)
                        .aspectRatio(1, contentMode: .fit)
                        .scaleEffect(shown || reduceMotion ? 1 : 0.2)
                        .opacity(shown || reduceMotion ? 1 : 0)
                        .animation(reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: 0.4)
                            .delay(delay + Double(i / Self.perRow) * 0.05), value: shown)
                }
            }
            if count > drawn {
                Text("+ \(count - drawn) more").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accentText)
            }
        }
        .accessibilityHidden(true)
    }
}
