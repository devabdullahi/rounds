import Foundation
import Testing
@testable import Rounds

@MainActor
@Suite("Paywall model")
struct PaywallModelTests {
    @Test func yearlyLeadsAndCarriesTheBadge() async {
        let model = PaywallModel(store: MockSubscriptionStore())
        await model.loadPlans()
        #expect(model.plans.map(\.period) == [.year, .month, .week])
        #expect(model.selected?.period == .year)
        #expect(model.bestValueID == "com.abdul.rounds.yearly")
    }

    @Test func buyingOpensTheApp() async {
        let store = MockSubscriptionStore()
        let model = PaywallModel(store: store)
        await model.loadPlans()
        await model.buy()
        #expect(model.isEntitled == true)
        #expect(await store.purchased == ["com.abdul.rounds.yearly"])
    }

    @Test func cancellingKeepsThePaywall() async {
        let model = PaywallModel(store: MockSubscriptionStore(outcome: .cancelled))
        await model.loadPlans()
        await model.buy()
        #expect(model.isEntitled != true)
        #expect(model.problem == nil)
    }
}
