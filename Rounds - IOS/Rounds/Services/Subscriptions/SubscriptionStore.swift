import Foundation

/// The App Store, as the gate needs it: who holds a plan. Selling happens in Superwall's paywall,
/// which buys through StoreKit, so the purchases land in the same place this reads.
/// Live: StoreKit 2 (`StoreKitSubscriptionStore`); previews, tests and debug screens: `MockSubscriptionStore`.
protocol SubscriptionStore: Sendable {
    /// Re-syncs purchases made on another device or before a reinstall.
    func restore() async throws
    /// True while the student holds an active subscription.
    func isEntitled() async -> Bool
    /// The App Store plan they hold, for Settings; nil without one.
    func activePlan() async -> ActivePlan?
    /// The entitlement again whenever a transaction changes it (renewal, refund, a purchase elsewhere).
    func entitlementChanges() -> AsyncStream<Bool>
    /// True for a build not installed from the App Store (TestFlight, or run from Xcode), which skips
    /// the paywall while Rounds is in testing.
    func isPreRelease() async -> Bool
}
