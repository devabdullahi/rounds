import Foundation
import Testing
@testable import Rounds

@Suite("Paywall pricing")
struct PaywallPricingTests {
    private let plans = MockSubscriptionStore.launchPlans
    private let us = Locale(identifier: "en_US")
    private func plan(_ period: SubscriptionPlan.Period) -> SubscriptionPlan { plans.first { $0.period == period }! }

    @Test(arguments: [(SubscriptionPlan.Period.week, "$7.99/wk"), (.month, "$5.77/wk"), (.year, "$2.31/wk")])
    func perWeekPrices(period: SubscriptionPlan.Period, label: String) {
        #expect(PaywallPricing.perWeekLabel(plan(period), locale: us) == label)
    }

    @Test func savingIsAgainstWeeklyAndNeverRoundedUp() {
        #expect(PaywallPricing.saving(plan(.year), in: plans) == 71)    // 119.99 vs 52 × 7.99 = 415.48: 71.1%
        #expect(PaywallPricing.saving(plan(.month), in: plans) == 27)
        #expect(PaywallPricing.saving(plan(.week), in: plans) == nil)
    }

    @Test func trialTimelineRemindsTheDayBeforeBilling() {
        let steps = PaywallPricing.steps(plan(.year))
        #expect(steps.map(\.when) == ["Today", "Day 2", "Day 3"])
        #expect(steps.map(\.kind) == [.access, .reminder, .billing])
        #expect(steps[2].what.contains("$119.99"))
    }

    @Test func plansWithoutTrialSayTheyRenew() {
        #expect(PaywallPricing.steps(plan(.week)).map(\.when) == ["Today", "Every week"])
        #expect(PaywallPricing.appleButtonTitle(plan(.week)) == "Pay with Apple · $7.99/wk")
        #expect(PaywallPricing.appleButtonTitle(plan(.year)) == "Start free trial with Apple")
        let web = MockWebBilling.launchPlans
        #expect(PaywallPricing.webButtonTitle(web[0]) == "Pay on the website · $7.49/wk")
        #expect(PaywallPricing.webButtonTitle(web[2]) == "Start free trial on the website")
    }

    @Test func finePrintStatesPriceRenewalAndCancel() {
        let text = PaywallPricing.finePrint(plan(.year))
        #expect(text == "Free for 3 days, then $119.99/year. Renews automatically. Cancel anytime.")
    }

    @Test(arguments: [(StudyGoal?.some(.step2CK), "Your Step 2 CK plan is ready"), (.shelf, "Your shelf exam plan is ready"),
                      (.practicing, "Your practice plan is ready"), (nil, "Your practice plan is ready")])
    func headlineFollowsTheGoal(goal: StudyGoal?, text: String) {
        #expect(PaywallPricing.headline(for: goal) == text)
    }

    @Test func finePrintGivesBothPricesWhenTheWebIsOffered() {
        let text = PaywallPricing.finePrint(apple: plan(.year), web: MockWebBilling.launchPlans[2])
        #expect(text == "With Apple: 3 days free, then $119.99/year. On the website: 3 days free, then $109.99/year. Renews automatically. Cancel anytime.")
    }
}
