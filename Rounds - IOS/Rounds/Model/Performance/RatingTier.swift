import Foundation

/// The rating band a student is in. Bands start where the rating-tier badges do, so the profile's
/// tier, its "to next tier" bar and the badge collection never disagree.
struct RatingTier: Equatable, Sendable {
    let name: String
    /// The rating this band starts at; the progress bar fills from here.
    let floor: Int
    /// The band above, if any.
    let next: (name: String, rating: Int)?

    static func == (a: RatingTier, b: RatingTier) -> Bool { a.name == b.name }

    /// Every account starts unranked at 1200; Silver is the first band that's earned.
    static let ladder: [(name: String, rating: Int)] = [
        ("Unranked", AppState.residentFloor),
        ("Silver", BadgeCatalog.silverRating),
        ("Gold", BadgeCatalog.goldRating),
        ("Platinum", BadgeCatalog.platinumRating),
    ]

    static func of(_ rating: Int) -> RatingTier {
        let i = ladder.lastIndex { rating >= $0.rating } ?? 0
        return RatingTier(name: ladder[i].name, floor: ladder[i].rating, next: i + 1 < ladder.count ? ladder[i + 1] : nil)
    }

    /// How far through this band the rating is, 0…1; full at the top band.
    func progress(_ rating: Int) -> Double {
        guard let next else { return 1 }
        return min(1, max(0, Double(rating - floor) / Double(next.rating - floor)))
    }

    /// "100 to Silver", or "Top tier" once there's nowhere higher.
    func toNextLabel(_ rating: Int) -> String {
        guard let next else { return "Top tier" }
        return "\(max(0, next.rating - rating)) to \(next.name)"
    }

    /// "Silver tier", or "Unranked" before the first band.
    var label: String { floor == AppState.residentFloor ? name : "\(name) tier" }
}
