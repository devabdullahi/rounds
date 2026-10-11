import Foundation
import Observation

/// The subscription gate. Knows whether the student may use the app, loads the plans and buys one.
/// The app opens only while `isEntitled` is true; until the first check it's nil and nothing shows.
@MainActor
@Observable
final class PaywallModel {
    private(set) var plans: [SubscriptionPlan] = []
    var selectedID: String?
    /// Nil until the store has answered once.
    private(set) var isEntitled: Bool?
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
        isEntitled = await store.isEntitled()
        await loadPlans()
        for await entitled in store.entitlementChanges() {
            isEntitled = entitled
        }
    }

    func loadPlans() async {
        do {
            // Longest first: yearly leads and is chosen by default.
            plans = try await store.plans().sorted { $0.period > $1.period }
            if selectedID == nil || selected == nil { selectedID = plans.first?.id }
        } catch {
            problem = "Couldn't load the plans. Check your connection and try again."
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
            isEntitled = await store.isEntitled()
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

    #if DEBUG
    /// Debug screens other than the paywall open straight into the app.
    func debugUnlock() { isEntitled = true }
    #endif
}
