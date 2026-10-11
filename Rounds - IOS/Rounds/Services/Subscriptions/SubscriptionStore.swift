import Foundation

/// The App Store, as the paywall needs it. Live: StoreKit 2 (`StoreKitSubscriptionStore`);
/// previews, tests and debug screens: `MockSubscriptionStore`.
protocol SubscriptionStore: Sendable {
    /// The plans on sale, with this student's trial eligibility.
    func plans() async throws -> [SubscriptionPlan]
    func purchase(_ planID: String) async throws -> PurchaseOutcome
    /// Re-syncs purchases made on another device or before a reinstall.
    func restore() async throws
    /// True while the student holds an active subscription.
    func isEntitled() async -> Bool
    /// The App Store plan they hold, for Settings; nil without one.
    func activePlan() async -> ActivePlan?
    /// The entitlement again whenever a transaction changes it (renewal, refund, a purchase elsewhere).
    func entitlementChanges() -> AsyncStream<Bool>
    /// The App Store country ("USA"); paying on the web is offered only where Apple allows linking out.
    func storefrontCountry() async -> String?
    /// True for a build not installed from the App Store (TestFlight, or run from Xcode), which skips
    /// the paywall while Rounds is in testing.
    func isPreRelease() async -> Bool
}
