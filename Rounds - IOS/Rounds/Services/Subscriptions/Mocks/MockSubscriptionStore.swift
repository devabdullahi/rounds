import Foundation

/// An offline App Store for previews, tests and debug screens.
actor MockSubscriptionStore: SubscriptionStore {
    private var entitled: Bool
    /// What a restore finds: true turns the entitlement on, as if bought on another device.
    private let restoreFinds: Bool

    init(entitled: Bool = false, restoreFinds: Bool = false) {
        self.entitled = entitled
        self.restoreFinds = restoreFinds
    }

    func restore() async throws {
        if restoreFinds { entitled = true }
    }

    func isEntitled() async -> Bool { entitled }

    func currentTransactionIDs() async -> [String] { entitled ? ["2000000111"] : [] }

    func activePlan() async -> ActivePlan? {
        entitled ? ActivePlan(period: .year, periodEnd: .now.addingTimeInterval(3 * 86_400), isTrial: true, willRenew: true) : nil
    }

    nonisolated func entitlementChanges() -> AsyncStream<Bool> { AsyncStream { $0.finish() } }
}
