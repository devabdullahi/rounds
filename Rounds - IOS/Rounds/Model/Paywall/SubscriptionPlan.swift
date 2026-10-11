import Foundation

/// One subscription the student can buy, as the paywall shows it. Built from the store's product,
/// so prices are the App Store's, in the student's currency.
struct SubscriptionPlan: Identifiable, Sendable, Equatable {
    enum Period: Int, Sendable, Comparable {
        case week = 1, month, year

        static func < (a: Period, b: Period) -> Bool { a.rawValue < b.rawValue }

        var name: String {
            switch self {
            case .week: "Weekly"
            case .month: "Monthly"
            case .year: "Yearly"
            }
        }

        /// "week", for "billed every week".
        var unit: String {
            switch self {
            case .week: "week"
            case .month: "month"
            case .year: "year"
            }
        }

        /// "wk", for "$7.99/wk".
        var short: String {
            switch self {
            case .week: "wk"
            case .month: "mo"
            case .year: "yr"
            }
        }
    }

    /// The store's product id.
    let id: String
    let period: Period
    let price: Decimal
    /// The store's own formatting of `price` ("$79.99").
    let displayPrice: String
    let currencyCode: String
    /// Days of free trial this student can still get on this plan; nil when there's none or they've used it.
    let trialDays: Int?
}
