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
        await model.purchased()
        #expect(model.isEntitled == true)
    }

    @Test func restoringFindsAPlanBoughtElsewhere() async {
        let model = PaywallModel(store: MockSubscriptionStore(restoreFinds: true))
        await model.restore()
        #expect(model.isEntitled == true)
        #expect(model.problem == nil)
    }

    // MARK: A subscription belongs to the account that bought it

    @Test func thePhonesPurchaseOpensTheAppForTheAccountThatOwnsIt() async {
        let accounts = MockAccountSubscriptionService(claim: AccountAccess(entitled: true))
        let model = PaywallModel(store: MockSubscriptionStore(entitled: true), accounts: accounts, verifiesAccount: true)
        await model.refresh()
        #expect(model.isEntitled == true)
        #expect(model.takenBy == nil)
        #expect(await accounts.claimed == ["2000000111"])
    }

    @Test func anotherAccountOnAPayingPhoneIsKeptOutAndToldWhy() async {
        let accounts = MockAccountSubscriptionService(claim: AccountAccess(entitled: false, ownedBy: "j•••@gmail.com"))
        let model = PaywallModel(store: MockSubscriptionStore(entitled: true), accounts: accounts, verifiesAccount: true)
        await model.refresh()
        #expect(model.isEntitled == false)
        #expect(model.takenBy == "j•••@gmail.com")
    }

    @Test func theOwnerGetsInOnAPhoneThatNeverPaid() async {
        let accounts = MockAccountSubscriptionService(status: AccountAccess(entitled: true))
        let model = PaywallModel(store: MockSubscriptionStore(), accounts: accounts, verifiesAccount: true)
        await model.refresh()
        #expect(model.isEntitled == true)
        #expect(await accounts.claimed.isEmpty)
    }

    @Test func aNewAccountDoesNotInheritThePreviousAccountsAccess() async {
        let model = PaywallModel(store: MockSubscriptionStore(entitled: true), accounts: FailingAccountSubscriptionService(), verifiesAccount: true)
        await model.purchased()
        #expect(model.isEntitled == true)
        await model.accountChanged(signedIn: true)
        #expect(model.isEntitled == false)
    }

    @Test func anAccountWithoutAPlanSeesThePaywall() async {
        let model = PaywallModel(store: MockSubscriptionStore(), accounts: MockAccountSubscriptionService(), verifiesAccount: true)
        await model.refresh()
        #expect(model.isEntitled == false)
        #expect(model.takenBy == nil)
    }

    @Test func restoringWithNothingSaysSo() async {
        let model = PaywallModel(store: MockSubscriptionStore())
        await model.restore()
        #expect(model.isEntitled == false)
        #expect(model.problem == "No active subscription was found for this Apple Account.")
    }
}
