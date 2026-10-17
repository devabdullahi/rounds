import Foundation
import StoreKit

/// Subscriptions through StoreKit 2. Products are set up in App Store Connect (and mirrored in
/// `Rounds.storekit` for local testing); ids must match there.
struct StoreKitSubscriptionStore: SubscriptionStore {
    static let productIDs = ["com.abdul.rounds.weekly", "com.abdul.rounds.monthly", "com.abdul.rounds.yearly"]

    func plans() async throws -> [SubscriptionPlan] {
        var plans: [SubscriptionPlan] = []
        for product in try await Product.products(for: Self.productIDs) {
            guard let subscription = product.subscription, let period = Self.period(subscription.subscriptionPeriod) else { continue }
            var trialDays: Int?
            if let offer = subscription.introductoryOffer, offer.paymentMode == .freeTrial, await subscription.isEligibleForIntroOffer {
                trialDays = Self.days(offer.period)
            }
            plans.append(SubscriptionPlan(id: product.id, period: period, price: product.price, displayPrice: product.displayPrice,
                                          currencyCode: product.priceFormatStyle.currencyCode, trialDays: trialDays))
        }
        return plans
    }

    func purchase(_ planID: String) async throws -> PurchaseOutcome {
        guard let product = try await Product.products(for: [planID]).first else { throw StoreKitError.notAvailableInStorefront }
        switch try await product.purchase() {
        case .success(let verification):
            let transaction = try verification.payloadValue
            await transaction.finish()
            return .purchased
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: return .cancelled
        }
    }

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

    private static func days(_ period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day: period.value
        case .week: period.value * 7
        case .month: period.value * 30
        case .year: period.value * 365
        @unknown default: period.value
        }
    }
}
