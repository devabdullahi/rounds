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

    // MARK: One free graded case

    @Test func theFreeCaseOpensTheAppUntilItsUsed() async {
        let accounts = MockAccountSubscriptionService(status: AccountAccess(entitled: false, freeCase: true))
        let model = PaywallModel(store: MockSubscriptionStore(), accounts: accounts, verifiesAccount: true)
        await model.refresh()
        #expect(model.isEntitled == false)
        #expect(model.opensApp == true)
        await accounts.answerStatus(AccountAccess(entitled: false))
        await model.refresh()
        #expect(model.opensApp == false)
    }

    @Test func aPlanNeverCountsAsTheFreeCase() async {
        let accounts = MockAccountSubscriptionService(claim: AccountAccess(entitled: true), status: AccountAccess(entitled: true, freeCase: true))
        let model = PaywallModel(store: MockSubscriptionStore(entitled: true), accounts: accounts, verifiesAccount: true)
        await model.refresh()
        #expect(model.isEntitled == true)
        #expect(model.freeCase == false)
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

    @Test func movingThePlanHereOpensTheApp() async {
        let accounts = MockAccountSubscriptionService(claim: AccountAccess(entitled: false, ownedBy: "j•••@gmail.com"))
        let model = PaywallModel(store: MockSubscriptionStore(entitled: true), accounts: accounts, verifiesAccount: true)
        await model.refresh()
        await model.movePlanHere()
        #expect(await accounts.transferred == ["2000000111"])
        #expect(model.isEntitled == true)
        #expect(model.takenBy == nil)
    }

    @Test func aBoundPlanIsCheckedByStatusNotClaimedAgain() async {
        let accounts = MockAccountSubscriptionService(claim: AccountAccess(entitled: true), status: AccountAccess(entitled: true))
        let model = PaywallModel(store: MockSubscriptionStore(entitled: true), accounts: accounts, verifiesAccount: true)
        await model.refresh()
        await model.refresh()
        #expect(await accounts.claimed == ["2000000111"])
        #expect(model.isEntitled == true)
    }

    @Test func aBoundPlanThatMovedAwayIsClaimedAgainToSayWhere() async {
        // Bound on the first check; the status then says no, as after another account moved it.
        let accounts = MockAccountSubscriptionService(claim: AccountAccess(entitled: true), status: AccountAccess(entitled: false))
        let model = PaywallModel(store: MockSubscriptionStore(entitled: true), accounts: accounts, verifiesAccount: true)
        await model.refresh()
        await model.refresh()
        #expect(await accounts.claimed == ["2000000111", "2000000111"])
    }
}
