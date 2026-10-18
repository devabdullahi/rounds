import SwiftUI

/// "Take tests · 2 of 8" with a bar: how much of a list the student has worked through. The count
/// rolls to its new value. Used by the exam and the tests, so both halves of the workup read alike.
struct CountProgressCard: View {
    let title: String
    let done: Int
    let total: Int
    /// Spoken after the count, e.g. "examined".
    let accessibilityNoun: String
    var ready = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold))
                Spacer()
                if ready {
                    Text("\(done) of \(total)")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                        .contentTransition(.numericText(value: Double(done)))
                        .animation(Springs.pop, value: done)
                }
            }
            ProgressBar(value: total > 0 ? Double(done) / Double(total) : 0)
        }
        .card(padding: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(done) of \(total) \(accessibilityNoun)")
    }
}
