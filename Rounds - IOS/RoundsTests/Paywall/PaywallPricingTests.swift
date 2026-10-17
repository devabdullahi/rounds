import Foundation
import Testing
@testable import Rounds

@Suite("Paywall pricing")
struct PaywallPricingTests {
    private let plans = MockSubscriptionStore.launchPlans
    private let us = Locale(identifier: "en_US")
    private func plan(_ period: PlanPeriod) throws -> SubscriptionPlan { try #require(plans.first { $0.period == period }) }

    @Test(arguments: [(PlanPeriod.week, "$7.99/wk"), (.month, "$5.77/wk"), (.year, "$2.31/wk")])
    func perWeekPrices(period: PlanPeriod, label: String) throws {
        #expect(PaywallPricing.perWeekLabel(try plan(period), locale: us) == label)
    }

    @Test func savingIsAgainstWeeklyAndNeverRoundedUp() throws {
        #expect(PaywallPricing.saving(try plan(.year), in: plans) == 71)    // 119.99 vs 52 × 7.99 = 415.48: 71.1%
        #expect(PaywallPricing.saving(try plan(.month), in: plans) == 27)
        #expect(PaywallPricing.saving(try plan(.week), in: plans) == nil)
    }

    @Test func trialTimelineRemindsTheDayBeforeBilling() throws {
        let steps = PaywallPricing.steps(try plan(.year))
        #expect(steps.map(\.when) == ["Today", "Day 2", "Day 3"])
        #expect(steps.map(\.kind) == [.access, .reminder, .billing])
        #expect(steps[2].what.contains("$119.99"))
    }

    @Test func plansWithoutTrialSayTheyRenew() throws {
        #expect(PaywallPricing.steps(try plan(.week)).map(\.when) == ["Today", "Every week"])
        #expect(PaywallPricing.buttonTitle(try plan(.week)) == "Continue · $7.99/wk")
        #expect(PaywallPricing.buttonTitle(try plan(.year)) == "Start free trial")
    }

    @Test func detailLineShowsTrialOrBilling() throws {
        #expect(PaywallPricing.detail(try plan(.year)) == "3 days free, then $119.99/yr")
        #expect(PaywallPricing.detail(try plan(.month)) == "$24.99 billed monthly")
    }

    @Test func finePrintStatesPriceRenewalAndCancel() throws {
        #expect(PaywallPricing.finePrint(try plan(.year)) == "Free for 3 days, then $119.99/year. Renews automatically. Cancel anytime.")
        #expect(PaywallPricing.finePrint(try plan(.week)) == "$7.99 every week. Renews automatically. Cancel anytime.")
    }

    @Test(arguments: [(StudyGoal?.some(.step2CK), "Your Step 2 CK plan is ready"), (.shelf, "Your shelf exam plan is ready"),
                      (.practicing, "Your practice plan is ready"), (nil, "Your practice plan is ready")])
    func headlineFollowsTheGoal(goal: StudyGoal?, text: String) {
        #expect(PaywallPricing.headline(for: goal) == text)
    }
}
