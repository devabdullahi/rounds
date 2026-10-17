import Foundation

/// How often a plan bills. Our App Store products are one week, one month or one year.
enum PlanPeriod: Int, Sendable, Comparable {
    case week = 1, month, year

    static func < (a: PlanPeriod, b: PlanPeriod) -> Bool { a.rawValue < b.rawValue }

    var name: String {
        switch self {
        case .week: "Weekly"
        case .month: "Monthly"
        case .year: "Yearly"
        }
    }

    /// "week", for "your week starts at $7.99".
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
