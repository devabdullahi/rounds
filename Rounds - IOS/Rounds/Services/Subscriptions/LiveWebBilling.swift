import Foundation
import Supabase

/// Web payments through the stripe-billing edge function; access is read from `public.subscriptions`,
/// which only the server writes (from Stripe's webhook).
struct LiveWebBilling: WebBilling {
    let client: SupabaseClient

    func plans() async throws -> [SubscriptionPlan] {
        let reply: PricesReply = try await invoke(["action": "prices"])
        return reply.prices.compactMap { row in
            guard let period = Self.period(row.plan) else { return nil }
            let price = Decimal(row.amount)
            let code = row.currency.uppercased()
            return SubscriptionPlan(id: "web.\(row.plan)", period: period, price: price,
                                    displayPrice: price.formatted(.currency(code: code)), currencyCode: code, trialDays: row.trial_days)
        }
    }

    func checkoutURL(for plan: SubscriptionPlan.Period) async throws -> URL {
        let reply: URLReply = try await invoke(["action": "checkout", "plan": Self.name(plan)])
        guard let url = URL(string: reply.url) else { throw URLError(.badURL) }
        return url
    }

    func portalURL() async throws -> URL {
        let reply: URLReply = try await invoke(["action": "portal"])
        guard let url = URL(string: reply.url) else { throw URLError(.badURL) }
        return url
    }

    func activePlan() async -> ActivePlan? {
        guard let rows: [SubscriptionRow] = try? await client.from("subscriptions")
            .select("status, plan, current_period_end, cancel_at_period_end").execute().value,
              let row = rows.first(where: { ["trialing", "active", "past_due"].contains($0.status) && $0.current_period_end > .now }),
              let period = Self.period(row.plan) else { return nil }
        return ActivePlan(source: .web, period: period, periodEnd: row.current_period_end,
                          isTrial: row.status == "trialing", willRenew: !row.cancel_at_period_end)
    }

    private func invoke<Reply: Decodable>(_ body: [String: String]) async throws -> Reply {
        do {
            return try await client.invokeSigned("stripe-billing", body: body)
        } catch let FunctionsError.httpError(code, data) {
            let message = (try? JSONDecoder().decode(ErrorReply.self, from: data))?.error
            throw CaseServiceError(message: message.map { "\($0.prefix(1).uppercased())\($0.dropFirst())." } ?? "The server returned \(code).")
        }
    }

    private static func period(_ name: String) -> SubscriptionPlan.Period? {
        ["weekly": .week, "monthly": .month, "yearly": .year][name]
    }

    private static func name(_ period: SubscriptionPlan.Period) -> String {
        switch period {
        case .week: "weekly"
        case .month: "monthly"
        case .year: "yearly"
        }
    }
}

private struct PricesReply: Decodable {
    struct Row: Decodable { let plan: String; let amount: Double; let currency: String; let trial_days: Int? }
    let prices: [Row]
}

private struct URLReply: Decodable { let url: String }
private struct ErrorReply: Decodable { let error: String }

private struct SubscriptionRow: Decodable {
    let status: String
    let plan: String
    let current_period_end: Date
    let cancel_at_period_end: Bool
}
