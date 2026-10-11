import Foundation
import Observation

/// The subscription gate. Knows whether the student may use the app, loads the plans and buys one.
/// The app opens only while `isEntitled` is true; until the first check it's nil and nothing shows.
/// A plan counts from either source: the App Store (StoreKit) or the server (a web plan via Stripe).
@MainActor
@Observable
final class PaywallModel {
    private(set) var plans: [SubscriptionPlan] = []
    /// The same plans on the web, cheaper; empty outside the US App Store or before they load.
    private(set) var webPlans: [SubscriptionPlan] = []
    var selectedID: String?
    /// Nil until the store has answered once.
    private(set) var isEntitled: Bool?
    /// The plan held now, App Store first; shown in Settings.
    private(set) var activePlan: ActivePlan?
    private(set) var isWorking = false
    var problem: String?

    private let store: any SubscriptionStore
    private let web: (any WebBilling)?
    private let reminders: (any ReminderService)?
    /// Apple's answer, kept apart so a StoreKit update can't hide a web plan (or the reverse).
    private var storeEntitled = false
    private var webEntitled = false

    init(store: any SubscriptionStore, web: (any WebBilling)? = nil, reminders: (any ReminderService)? = nil) {
        self.store = store
        self.web = web
        self.reminders = reminders
    }

    /// The web version of the selected plan, offered as "Pay on the web".
    var webOffer: SubscriptionPlan? {
        guard let selected else { return nil }
        return webPlans.first { $0.period == selected.period }
    }

    var selected: SubscriptionPlan? { plans.first { $0.id == selectedID } }

    /// The plan with the biggest saving, the one that carries the badge.
    var bestValueID: String? {
        plans.compactMap { plan in PaywallPricing.saving(plan, in: plans).map { (plan.id, $0) } }.max { $0.1 < $1.1 }?.0
    }

    /// Checks access, loads the plans, then follows entitlement changes for as long as the app runs.
    func start() async {
        await refresh()
        await loadPlans()
        for await entitled in store.entitlementChanges() {
            storeEntitled = entitled
            isEntitled = storeEntitled || webEntitled
        }
    }

    /// Asks both sources again: on launch, on return from the web checkout, and when the app comes back.
    func refresh() async {
        // Testing: TestFlight and Xcode installs go straight in; only App Store installs need a plan.
        if await store.isPreRelease() {
            isEntitled = true
            return
        }
        let storePlan = await store.activePlan()
        let webPlan = await web?.activePlan()
        storeEntitled = await store.isEntitled()
        webEntitled = webPlan != nil
        activePlan = storePlan ?? webPlan
        #if DEBUG
        if debugUnlocked { return }
        #endif
        isEntitled = storeEntitled || webEntitled
    }

    func loadPlans() async {
        do {
            // Longest first: yearly leads and is chosen by default.
            plans = try await store.plans().sorted { $0.period > $1.period }
            if selectedID == nil || selected == nil { selectedID = plans.first?.id }
        } catch {
            problem = "Couldn't load the plans. Check your connection and try again."
        }
        // Apple allows linking out to a web checkout only on the US App Store.
        if let web, await store.storefrontCountry() == "USA" {
            webPlans = (try? await web.plans()) ?? []
        }
    }

    func buy() async {
        guard let plan = selected, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            switch try await store.purchase(plan.id) {
            case .purchased:
                storeEntitled = true
                isEntitled = true
                if let days = plan.trialDays { await remindBeforeBilling(plan, trialDays: days) }
            case .pending:
                problem = "Your purchase is waiting for approval. Rounds opens as soon as it goes through."
            case .cancelled:
                break
            }
        } catch {
            problem = "The purchase didn't go through. You haven't been charged."
        }
    }

    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await store.restore()
            await refresh()
            if isEntitled == false { problem = "No active subscription was found for this Apple Account." }
        } catch {
            problem = "Couldn't reach the App Store. Try again in a moment."
        }
    }

    /// Keeps the timeline's promise: a reminder 24 hours before the trial bills.
    private func remindBeforeBilling(_ plan: SubscriptionPlan, trialDays: Int) async {
        guard let date = Calendar.current.date(byAdding: .day, value: max(1, trialDays - 1), to: .now) else { return }
        await reminders?.scheduleTrialReminder(
            at: date,
            title: "Your Rounds trial ends tomorrow",
            body: "Your \(plan.period.unit) starts at \(plan.displayPrice). Cancel in Settings before then to pay nothing.")
    }

    /// Stripe's billing portal for a web plan, to open in Safari. (An App Store plan is managed in
    /// Apple's own sheet, which the view presents.)
    func webPortalURL() async -> URL? {
        guard let web, !isWorking else { return nil }
        isWorking = true
        defer { isWorking = false }
        do {
            return try await web.portalURL()
        } catch {
            problem = error.localizedDescription
            return nil
        }
    }

    /// The Stripe Checkout page for the selected plan, to open in Safari.
    func webCheckoutURL() async -> URL? {
        guard let web, let plan = webOffer, !isWorking else { return nil }
        isWorking = true
        defer { isWorking = false }
        do {
            return try await web.checkoutURL(for: plan.period)
        } catch {
            problem = error.localizedDescription
            return nil
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
