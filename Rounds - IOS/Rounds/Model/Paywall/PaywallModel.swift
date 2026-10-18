import Foundation
import Observation

/// The subscription gate. Knows whether the student may use the app; the app opens only while
/// `isEntitled` is true, and until the first check it's nil and nothing shows. Selling is Superwall's
/// paywall (designed in its dashboard); this model hears what it sold and asks the App Store the rest.
///
/// A subscription belongs to the Rounds account that bought it. The phone's purchase is claimed for
/// the signed-in account, and the server's answer decides access, so another account on a paying
/// phone sees the paywall and the owner gets in on any phone.
@MainActor
@Observable
final class PaywallModel {
    /// Nil until the store has answered once.
    private(set) var isEntitled: Bool?
    /// The plan held now; shown in Settings.
    private(set) var activePlan: ActivePlan?
    private(set) var isWorking = false
    var problem: String?
    /// The phone's subscription belongs to another Rounds account (masked email); the gate says so.
    private(set) var takenBy: String?

    private let store: any SubscriptionStore
    private let accounts: (any AccountSubscriptionService)?
    /// Whether access comes from the account (server) or from the phone. Xcode runs buy from the local
    /// StoreKit file, whose purchases Apple's servers have never seen, so they check the phone.
    private let verifiesAccount: Bool

    nonisolated static var verifiesAccountByDefault: Bool {
        #if DEBUG
        false
        #else
        true
        #endif
    }

    init(store: any SubscriptionStore, accounts: (any AccountSubscriptionService)? = nil,
         verifiesAccount: Bool = PaywallModel.verifiesAccountByDefault) {
        self.store = store
        self.accounts = accounts
        self.verifiesAccount = verifiesAccount
    }

    /// Checks access, then follows entitlement changes for as long as the app runs.
    func start() async {
        await refresh()
        for await _ in store.entitlementChanges() {
            await refresh()
        }
    }

    /// Asks the App Store again: on launch, when the app comes back, and after the paywall closes.
    func refresh() async {
        activePlan = await store.activePlan()
        let onPhone = await store.isEntitled()
        #if DEBUG
        if debugUnlocked { return }
        #endif
        guard verifiesAccount, let accounts else {
            isEntitled = onPhone
            return
        }
        do {
            let access = try await accountAccess(accounts, phoneHasPlan: onPhone)
            takenBy = access.entitled ? nil : access.ownedBy
            isEntitled = access.entitled
        } catch {
            // Server unreachable: keep the last answer; with none yet, the gate stays closed.
            if isEntitled == nil { isEntitled = false }
        }
    }

    /// The phone's purchases are claimed for this account first (binding a new one, refreshing an
    /// owned one); then the account's own status counts, for an owner on a phone that didn't buy.
    private func accountAccess(_ accounts: any AccountSubscriptionService, phoneHasPlan: Bool) async throws -> AccountAccess {
        var ownedBy: String?
        if phoneHasPlan {
            for id in await store.currentTransactionIDs() {
                let claim = try await accounts.claim(transactionID: id)
                if claim.entitled { return claim }
                ownedBy = claim.ownedBy ?? ownedBy
            }
        }
        let status = try await accounts.status()
        return status.entitled ? status : AccountAccess(entitled: false, ownedBy: ownedBy)
    }

    /// The paywall sold a plan: open the app now.
    func purchased() async {
        isEntitled = true
        activePlan = await store.activePlan()
        // Binds the new purchase to this account on the server. Only binds: the phone can lag a
        // moment behind a purchase, and a re-check then must not close the gate just opened.
        if verifiesAccount, let accounts {
            for id in await store.currentTransactionIDs() { _ = try? await accounts.claim(transactionID: id) }
        }
    }

    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await store.restore()
            await refresh()
            if isEntitled == false, takenBy == nil { problem = "No active subscription was found for this Apple Account." }
        } catch {
            problem = "Couldn't reach the App Store. Try again in a moment."
        }
    }

    #if DEBUG
    /// Debug screens other than the paywall open straight into the app.
    private var debugUnlocked = false
    func debugUnlock() {
        debugUnlocked = true
        isEntitled = true
    }
    #endif
}
