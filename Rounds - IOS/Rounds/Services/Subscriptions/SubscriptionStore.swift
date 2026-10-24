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
    /// Ids of this phone's active subscription transactions, to hand to the account that owns them.
    func currentTransactionIDs() async -> [String]
    /// Apple's signed copy of one of those transactions (StoreKit's JWS). Only the Apple ID that
    /// bought the plan has it, so the server takes it as proof when a plan moves between accounts.
    func signedTransaction(id: String) async -> String?
    /// The entitlement again whenever a transaction changes it (renewal, refund, a purchase elsewhere).
    func entitlementChanges() -> AsyncStream<Bool>
}
