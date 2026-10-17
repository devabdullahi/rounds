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

    @Test func aPurchaseFromThePaywallOpensTheApp() async {
        let model = PaywallModel(store: MockSubscriptionStore())
        await model.refresh()
        await model.purchased(PurchasedPlan(displayPrice: "$119.99", period: .year, trialDays: 3))
        #expect(model.isEntitled == true)
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
