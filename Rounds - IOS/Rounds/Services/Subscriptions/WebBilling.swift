import Foundation

/// Paying on the web: Stripe Checkout, opened in Safari (US App Store only, where Apple allows
/// linking out). Live: `LiveWebBilling` (the stripe-billing function and the subscriptions table).
protocol WebBilling: Sendable {
    /// The web plans with their prices, as `SubscriptionPlan`s so the paywall prices them the same way.
    func plans() async throws -> [SubscriptionPlan]
    /// A Stripe Checkout page for this student and plan.
    func checkoutURL(for plan: SubscriptionPlan.Period) async throws -> URL
    /// Stripe's billing portal, to cancel or change card.
    func portalURL() async throws -> URL
    /// The plan the server records for this student (a web plan today), while it gives access; nil without one.
    func activePlan() async -> ActivePlan?
}
