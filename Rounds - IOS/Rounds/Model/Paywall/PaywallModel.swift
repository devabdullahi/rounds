import Foundation
import Observation

/// The subscription gate. Knows whether the student may use the app; the app opens only while
/// `isEntitled` is true, and until the first check it's nil and nothing shows. Selling is Superwall's
/// paywall (designed in its dashboard); this model hears what it sold and asks the App Store the rest.
///
/// A subscription belongs to one Rounds account at a time. The phone's purchase is claimed for the
/// signed-in account and the server's answer decides access: the owner gets in on any phone, and
/// another account on a paying phone is told whose plan it is and may move it here (`movePlanHere`).
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
    /// The purchase `takenBy` has, for moving it here.
    private var takenTransactionID: String?
    /// Purchases the server already bound to this account: later checks ask `status` instead of
    /// claiming again (each claim is an App Store call, with a daily allowance).
    private var boundIDs: Set<String> = []
    /// Bumped when the account changes, so an answer for the previous account is dropped.
    private var generation = 0

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
        let asked = generation
        do {
            let access = try await accountAccess(accounts, phoneHasPlan: onPhone)
            guard asked == generation else { return }
            takenBy = access.entitled ? nil : access.ownedBy
            takenTransactionID = access.entitled ? nil : access.takenTransactionID
            isEntitled = access.entitled
        } catch {
            guard asked == generation else { return }
            // Server unreachable: keep the last answer; with none yet, the gate stays closed.
            if isEntitled == nil { isEntitled = false }
        }
    }

    /// A different account signed in (or out): forget the last account's answer so nothing it paid
    /// for carries over, and check again for the new one. Until the server answers, the gate is shut.
    func accountChanged(signedIn: Bool) async {
        #if DEBUG
        if debugUnlocked { return }
        #endif
        generation += 1
        isEntitled = nil
        takenBy = nil
        takenTransactionID = nil
        boundIDs = []
        activePlan = nil
        if signedIn { await refresh() }
    }

    /// The phone's purchases are claimed for this account first (binding a new one, refreshing an
    /// owned one); then the account's own status counts, for an owner on a phone that didn't buy.
    private func accountAccess(_ accounts: any AccountSubscriptionService, phoneHasPlan: Bool) async throws -> AccountAccess {
        let ids = phoneHasPlan ? await store.currentTransactionIDs() : []
        // Already bound here: the account's status answers without another App Store call. If it
        // says no (the plan moved to another account, or lapsed), claim again to learn which.
        if ids.contains(where: boundIDs.contains) {
            let status = try await accounts.status()
            if status.entitled { return status }
            boundIDs.subtract(ids)
        }
        var taken: AccountAccess?
        for id in ids {
            let claim = try await accounts.claim(transactionID: id)
            if claim.entitled {
                boundIDs.insert(id)
                return claim
            }
            if let owner = claim.ownedBy { taken = AccountAccess(entitled: false, ownedBy: owner, takenTransactionID: id) }
        }
        let status = try await accounts.status()
        return status.entitled ? status : taken ?? status
    }

    /// The paywall sold a plan: open the app now, then bind the purchase to this account. A claim
    /// that fails or finds nothing doesn't close the gate (the phone can lag a moment behind a
    /// purchase); only a server saying another account has it does.
    func purchased() async {
        isEntitled = true
        activePlan = await store.activePlan()
        guard verifiesAccount, let accounts else { return }
        let asked = generation
        for id in await store.currentTransactionIDs() {
            guard let claim = try? await accounts.claim(transactionID: id), asked == generation else { continue }
            if claim.entitled { boundIDs.insert(id) }
            else if let owner = claim.ownedBy {
                takenBy = owner
                takenTransactionID = id
                isEntitled = false
            }
        }
    }

    /// The student asked to move the phone's plan to this account; the account that had it loses it.
    func movePlanHere() async {
        guard !isWorking, let accounts, let id = takenTransactionID else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let access = try await accounts.transfer(transactionID: id)
            if access.entitled {
                boundIDs.insert(id)
                takenBy = nil
                takenTransactionID = nil
                isEntitled = true
            } else {
                problem = "That plan has ended. Choose a plan to keep going."
                await refresh()
            }
        } catch {
            problem = "Couldn't move the plan. Try again in a moment."
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
