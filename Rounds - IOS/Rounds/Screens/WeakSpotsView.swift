import SwiftUI

/// Where the student loses points, by scoring category, over a chosen stretch of time.
/// Opened from the Profile card of the same name.
struct WeakSpotsView: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var timeframe: Timeframe = .month

    private var result: (stats: [CategoryStat], cases: Int) { Performance.stats(app.graded, in: timeframe) }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Where you lose points") {
                IconButton(glyph: .chevronLeft, label: "Back") { dismiss() }
            } trailing: { EmptyView() }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Segmented(options: Timeframe.allCases.map { ($0, $0.label) }, selection: $timeframe)

                    if result.cases == 0 {
                        empty
                    } else {
                        Text("Across \(result.cases) graded case\(result.cases == 1 ? "" : "s"). Biggest losses first.")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.muted)
                        VStack(spacing: 0) {
                            ForEach(Array(result.stats.enumerated()), id: \.element.id) { i, stat in
                                if i > 0 { Hairline() }
                                row(stat, weakest: i == 0 && stat.lost > 0)
                            }
                        }
                        .listSurface()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .animation(Springs.slide, value: timeframe)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.bg)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func row(_ stat: CategoryStat, weakest: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(stat.category.label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(weakest ? Theme.warnText : Theme.text)
                Spacer()
                Text("\(Int((stat.share * 100).rounded()))%").font(.mono(15, weight: .medium))
            }
            ProgressBar(value: stat.share, color: weakest ? Theme.warn : Theme.accent)
            HStack(alignment: .firstTextBaseline) {
                Text(stat.category.detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Text(stat.lost == 0 ? "No points lost" : "\(stat.lost) of \(stat.points.max) pts lost")
                    .font(.system(size: 13))
                    .foregroundStyle(stat.lost == 0 ? Theme.good : Theme.muted)
                    .fixedSize()
            }
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text(app.graded.isEmpty ? "No graded cases yet" : "No graded cases in this stretch")
                .font(.system(size: 17, weight: .semibold))
            Text(app.graded.isEmpty
                 ? "Finish a case and your attending's scoring shows up here, part by part."
                 : "Pick a longer stretch, or finish a case to add one.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
    }
}
