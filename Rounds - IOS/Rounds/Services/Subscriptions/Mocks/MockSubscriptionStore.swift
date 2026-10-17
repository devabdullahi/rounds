import Foundation

/// Offline plans at the launch prices, for previews, tests and debug screens. Purchases succeed
/// immediately unless `outcome` says otherwise.
actor MockSubscriptionStore: SubscriptionStore {
    private var entitled: Bool
    private let outcome: PurchaseOutcome
    /// What a restore finds: true turns the entitlement on, as if bought on another device.
    private let restoreFinds: Bool
    private(set) var purchased: [String] = []

    init(entitled: Bool = false, outcome: PurchaseOutcome = .purchased, restoreFinds: Bool = false) {
        self.entitled = entitled
        self.outcome = outcome
        self.restoreFinds = restoreFinds
    }

    static let launchPlans = [
        SubscriptionPlan(id: "com.abdul.rounds.weekly", period: .week, price: 7.99, displayPrice: "$7.99", currencyCode: "USD", trialDays: nil),
        SubscriptionPlan(id: "com.abdul.rounds.monthly", period: .month, price: 24.99, displayPrice: "$24.99", currencyCode: "USD", trialDays: nil),
        SubscriptionPlan(id: "com.abdul.rounds.yearly", period: .year, price: 119.99, displayPrice: "$119.99", currencyCode: "USD", trialDays: 3),
    ]

    func plans() async throws -> [SubscriptionPlan] { Self.launchPlans }

    func purchase(_ planID: String) async throws -> PurchaseOutcome {
        purchased.append(planID)
        if outcome == .purchased { entitled = true }
        return outcome
    }

    func restore() async throws {
        if restoreFinds { entitled = true }
    }

    func isEntitled() async -> Bool { entitled }

    func activePlan() async -> ActivePlan? {
        entitled ? ActivePlan(period: .year, periodEnd: .now.addingTimeInterval(3 * 86_400), isTrial: true, willRenew: true) : nil
    }

    nonisolated func entitlementChanges() -> AsyncStream<Bool> { AsyncStream { $0.finish() } }
}
