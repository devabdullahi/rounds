import Foundation
import Observation

/// The subscription gate. Knows whether the student may use the app; the app opens only while
/// `isEntitled` is true, and until the first check it's nil and nothing shows. Selling is Superwall's
/// paywall (designed in its dashboard); this model hears what it sold and asks the App Store the rest.
@MainActor
@Observable
final class PaywallModel {
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

    /// Checks access, then follows entitlement changes for as long as the app runs.
    func start() async {
        await refresh()
        for await entitled in store.entitlementChanges() {
            if await store.isPreRelease() { continue }
            isEntitled = entitled
            activePlan = await store.activePlan()
        }
    }

    /// Asks the App Store again: on launch, when the app comes back, and after the paywall closes.
    func refresh() async {
        // Testing: TestFlight and Xcode installs go straight in; only App Store installs need a plan.
        if await store.isPreRelease() {
            isEntitled = true
            return
        }
        activePlan = await store.activePlan()
        let entitled = await store.isEntitled()
        #if DEBUG
        if debugUnlocked { return }
        #endif
        isEntitled = entitled
    }

    /// The paywall sold a plan: open the app now, and remind them the day before a trial bills.
    func purchased(_ plan: PurchasedPlan) async {
        isEntitled = true
        activePlan = await store.activePlan()
        if let days = plan.trialDays { await remindBeforeBilling(plan, trialDays: days) }
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

    /// Keeps the trial's promise: a reminder 24 hours before it bills.
    private func remindBeforeBilling(_ plan: PurchasedPlan, trialDays: Int) async {
        guard let date = Calendar.current.date(byAdding: .day, value: max(1, trialDays - 1), to: .now) else { return }
        let then = plan.period.map { "Your \($0.unit) starts at \(plan.displayPrice)." } ?? "Your plan starts at \(plan.displayPrice)."
        await reminders?.scheduleTrialReminder(
            at: date,
            title: "Your Rounds trial ends tomorrow",
            body: "\(then) Cancel in Settings before then to pay nothing.")
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
