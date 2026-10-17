import Foundation

/// One subscription the student can buy, as the paywall shows it. Built from the store's product,
/// so prices are the App Store's, in the student's currency.
struct SubscriptionPlan: Identifiable, Sendable, Equatable {
    /// The store's product id.
    let id: String
    let period: PlanPeriod
    let price: Decimal
    /// The store's own formatting of `price` ("$119.99").
    let displayPrice: String
    let currencyCode: String
    /// Days of free trial this student can still get on this plan; nil when there's none or they've used it.
    let trialDays: Int?
}
