import Foundation

enum Performance {
    /// Category totals for the cases in a timeframe, where the most points were lost first, and how
    /// many cases they cover. Cases graded before the breakdown existed are left out.
    static func stats(_ cases: [GradedCase], in timeframe: Timeframe, now: Date = .now) -> (stats: [CategoryStat], cases: Int) {
        let counted = cases.filter { !$0.breakdown.isEmpty && timeframe.includes($0.submittedAt, now: now) }
        let stats = ScoreCategory.allCases.map { category in
            let points = counted.compactMap { $0.breakdown[category] }
                .reduce(Points(got: 0, max: 0)) { Points(got: $0.got + $1.got, max: $0.max + $1.max) }
            return CategoryStat(category: category, points: points)
        }
        .filter { $0.points.max > 0 }
        .sorted { ($0.share, $1.points.max) < ($1.share, $0.points.max) }
        return (stats, counted.count)
    }
}
