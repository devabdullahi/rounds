import Foundation

/// One category's totals over a set of cases.
struct CategoryStat: Identifiable, Hashable, Sendable {
    let category: ScoreCategory
    let points: Points
    var id: ScoreCategory { category }
    /// Share of the available points earned, 0…1.
    var share: Double { points.max == 0 ? 1 : Double(points.got) / Double(points.max) }
    var lost: Int { points.max - points.got }
}
