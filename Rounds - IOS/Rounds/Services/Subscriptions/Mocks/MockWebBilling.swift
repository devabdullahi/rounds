import Foundation

/// Web plans at the launch web prices, for previews, tests and the paywall debug screen.
actor MockWebBilling: WebBilling {
    private let active: Bool

    init(active: Bool = false) {
        self.active = active
    }

    static let launchPlans = [
        SubscriptionPlan(id: "web.weekly", period: .week, price: 7.49, displayPrice: "$7.49", currencyCode: "USD", trialDays: nil),
        SubscriptionPlan(id: "web.monthly", period: .month, price: 22.99, displayPrice: "$22.99", currencyCode: "USD", trialDays: nil),
        SubscriptionPlan(id: "web.yearly", period: .year, price: 109.99, displayPrice: "$109.99", currencyCode: "USD", trialDays: 3),
    ]

    func plans() async throws -> [SubscriptionPlan] { Self.launchPlans }

    func checkoutURL(for plan: SubscriptionPlan.Period) async throws -> URL {
        guard let url = URL(string: "https://checkout.stripe.com/test") else { throw URLError(.badURL) }
        return url
    }

    func portalURL() async throws -> URL {
        guard let url = URL(string: "https://billing.stripe.com/test") else { throw URLError(.badURL) }
        return url
    }

    func activePlan() async -> ActivePlan? {
        active ? ActivePlan(source: .web, period: .month, periodEnd: .now.addingTimeInterval(20 * 86_400), isTrial: false, willRenew: true) : nil
    }
}
