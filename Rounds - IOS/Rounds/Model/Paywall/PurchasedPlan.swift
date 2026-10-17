import Foundation

/// What the paywall just sold, as much as the app needs to keep the trial's promise: a reminder
/// the day before it bills. Mapped from Superwall's product in `Services/Subscriptions`.
struct PurchasedPlan: Equatable, Sendable {
    /// The App Store's own formatting of the price ("$119.99").
    let displayPrice: String
    let period: PlanPeriod?
    /// Free-trial days on this purchase; nil without a trial.
    let trialDays: Int?
}
