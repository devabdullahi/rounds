import SwiftUI

/// Debrief card: the points each part of the case earned, so the score says where it came from.
/// A part under half its points is drawn in the warning color: that's the one to practice.
struct ScoreBreakdownCard: View {
    struct Row: Identifiable {
        let label: String
        let got: Int
        let max: Int
        var id: String { label }
        var fraction: Double { max > 0 ? Double(got) / Double(max) : 0 }
        var isWeak: Bool { max > 0 && fraction < 0.5 }
    }

    let rows: [Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where your points came from")
                .font(.system(size: 17, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 12) {
                ForEach(rows) { row in
                    VStack(spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.label).font(.system(size: 15))
                            Spacer(minLength: 8)
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                Text("\(row.got)").font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(row.isWeak ? Theme.warnText : Theme.text)
                                Text("/\(row.max)").font(.system(size: 15)).foregroundStyle(Theme.muted)
                            }
                        }
                        ProgressBar(value: row.fraction, color: row.isWeak ? Theme.warn : Theme.accent, height: 6)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(row.label): \(row.got) of \(row.max) points")
                }
            }
        }
        .foregroundStyle(Theme.text)
        .card(radius: 20, padding: 18)
    }
}
