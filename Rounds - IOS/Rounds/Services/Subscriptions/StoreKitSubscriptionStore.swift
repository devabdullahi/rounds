import Foundation
import StoreKit

/// Subscriptions through StoreKit 2. Products are set up in App Store Connect (and mirrored in
/// `Rounds.storekit` for local testing); ids must match there and in Superwall's paywalls, which sell them.
struct StoreKitSubscriptionStore: SubscriptionStore {
    static let productIDs = ["com.abdul.rounds.weekly", "com.abdul.rounds.monthly", "com.abdul.rounds.yearly"]

    func restore() async throws {
        try await AppStore.sync()
    }

    func isEntitled() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    func currentTransactionIDs() async -> [String] {
        var ids: [String] = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                ids.append(String(transaction.id))
            }
        }
        return ids
    }

    func signedTransaction(id: String) async -> String? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, String(transaction.id) == id {
                return result.jwsRepresentation
            }
        }
        return nil
    }

    func activePlan() async -> ActivePlan? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil, let end = transaction.expirationDate,
                  let product = try? await Product.products(for: [transaction.productID]).first,
                  let unit = product.subscription.flatMap({ Self.period($0.subscriptionPeriod) }) else { continue }
            var willRenew = true
            if let status = try? await product.subscription?.status.first,
               case .verified(let renewal) = status.renewalInfo {
                willRenew = renewal.willAutoRenew
            }
            return ActivePlan(period: unit, periodEnd: end, isTrial: Self.isFreeTrial(transaction), willRenew: willRenew)
        }
        return nil
    }

    func entitlementChanges() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let task = Task {
                for await update in Transaction.updates {
                    if case .verified(let transaction) = update { await transaction.finish() }
                    continuation.yield(await isEntitled())
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Our only introductory offer is the yearly free trial, so before iOS 17.2 (no `offer`) an
    /// introductory transaction means a trial.
    private static func isFreeTrial(_ transaction: Transaction) -> Bool {
        if #available(iOS 17.2, *) { return transaction.offer?.paymentMode == .freeTrial }
        return transaction.offerType == .introductory
    }

    private static func period(_ period: Product.SubscriptionPeriod) -> PlanPeriod? {
        switch (period.unit, period.value) {
        case (.week, 1): .week
        case (.month, 1): .month
        case (.year, 1): .year
        default: nil
        }
    }
}
