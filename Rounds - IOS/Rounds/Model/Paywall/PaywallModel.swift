import Foundation
import Observation

/// The subscription gate. Knows whether the student may use the app, loads the plans and buys one.
/// The app opens only while `isEntitled` is true; until the first check it's nil and nothing shows.
@MainActor
@Observable
final class PaywallModel {
    /// Longest first: yearly leads and is chosen by default.
    private(set) var plans: [SubscriptionPlan] = []
    var selectedID: String?
    /// True when the plans couldn't load, so the paywall shows a retry instead of a spinner.
    private(set) var plansFailed = false
    /// Nil until the store has answered once.
    private(set) var isEntitled: Bool?
    /// The plan held now; shown in Settings.
    private(set) var activePlan: ActivePlan?
    private(set) var isWorking = false
    var problem: String?

    private let store: any SubscriptionStore
    private let reminders: (any ReminderService)?

    init(store: any SubscriptionStore, reminders: (any ReminderService)? = nil) {
        self.store = store
        self.reminders = reminders
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
            isEntitled = entitled
            activePlan = await store.activePlan()
        }
    }

    /// Asks the App Store again: on launch, when the app comes back, and after a restore.
    func refresh() async {
        activePlan = await store.activePlan()
        let entitled = await store.isEntitled()
        #if DEBUG
        if debugUnlocked { return }
        #endif
        isEntitled = entitled
    }

    func loadPlans() async {
        do {
            plans = try await store.plans().sorted { $0.period > $1.period }
            plansFailed = plans.isEmpty
            if selected == nil { selectedID = plans.first?.id }
        } catch {
            plansFailed = true
        }
    }

    func buy() async {
        guard let plan = selected, !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            switch try await store.purchase(plan.id) {
            case .purchased:
                isEntitled = true
                activePlan = await store.activePlan()
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
        guard let date = Calendar.current.date(byAdding: .day, value: PaywallPricing.reminderDay(trialDays: trialDays), to: .now) else { return }
        await reminders?.scheduleTrialReminder(
            at: date,
            title: "Your Rounds trial ends tomorrow",
            body: "Your \(plan.period.unit) starts at \(plan.displayPrice). Cancel in Settings before then to pay nothing.")
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
