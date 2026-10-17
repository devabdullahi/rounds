import Foundation
import Testing
@testable import Rounds

@MainActor
@Suite("Paywall model")
struct PaywallModelTests {
    @Test func noPlanKeepsTheGateClosed() async {
        let model = PaywallModel(store: MockSubscriptionStore())
        await model.refresh()
        #expect(model.isEntitled == false)
        #expect(model.activePlan == nil)
    }

    @Test func aPlanOpensTheApp() async {
        let model = PaywallModel(store: MockSubscriptionStore(entitled: true))
        await model.refresh()
        #expect(model.isEntitled == true)
        #expect(model.activePlan?.period == .year)
    }

    @Test func yearlyLeadsAndIsChosenFirst() async {
        let model = PaywallModel(store: MockSubscriptionStore())
        await model.loadPlans()
        #expect(model.plans.map(\.period) == [.year, .month, .week])
        #expect(model.selected?.period == .year)
        #expect(model.bestValueID == "com.abdul.rounds.yearly")
        #expect(model.plansFailed == false)
    }

    @Test func buyingTheSelectedPlanOpensTheApp() async {
        let store = MockSubscriptionStore()
        let model = PaywallModel(store: store)
        await model.refresh()
        await model.loadPlans()
        model.selectedID = "com.abdul.rounds.monthly"
        await model.buy()
        #expect(model.isEntitled == true)
        #expect(await store.purchased == ["com.abdul.rounds.monthly"])
    }

    @Test(arguments: [(PurchaseOutcome.cancelled, nil as String?),
                      (.pending, "Your purchase is waiting for approval. Rounds opens as soon as it goes through.")])
    func anUnfinishedPurchaseKeepsTheGateClosed(outcome: PurchaseOutcome, problem: String?) async {
        let model = PaywallModel(store: MockSubscriptionStore(outcome: outcome))
        await model.refresh()
        await model.loadPlans()
        await model.buy()
        #expect(model.isEntitled == false)
        #expect(model.problem == problem)
    }

    @Test func restoringFindsAPlanBoughtElsewhere() async {
        let model = PaywallModel(store: MockSubscriptionStore(restoreFinds: true))
        await model.restore()
        #expect(model.isEntitled == true)
        #expect(model.problem == nil)
    }

    @Test func restoringWithNothingSaysSo() async {
        let model = PaywallModel(store: MockSubscriptionStore())
        await model.restore()
        #expect(model.isEntitled == false)
        #expect(model.problem == "No active subscription was found for this Apple Account.")
    }
}
