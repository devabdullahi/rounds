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

    @Test func aWebPlanOpensTheAppToo() async {
        let model = PaywallModel(store: MockSubscriptionStore(), web: MockWebBilling(active: true))
        await model.refresh()
        #expect(model.isEntitled == true)
    }

    @Test func theWebOfferMatchesTheSelectedPlan() async {
        let model = PaywallModel(store: MockSubscriptionStore(), web: MockWebBilling())
        await model.loadPlans()
        #expect(model.webOffer?.displayPrice == "$99.99")
        model.selectedID = "com.abdul.rounds.weekly"
        #expect(model.webOffer?.displayPrice == "$6.99")
    }
}
