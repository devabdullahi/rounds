import Foundation
import Testing
@testable import Rounds

@Suite("Active plan")
struct ActivePlanTests {
    private let us = Locale(identifier: "en_US")
    private var calendar: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }

    @Test func renewingPlanSaysWhenItRenews() {
        let plan = ActivePlan(source: .web, period: .year, periodEnd: date(2027, 10, 14), isTrial: false, willRenew: true)
        #expect(plan.summary(locale: us, calendar: calendar, now: date(2026, 10, 11)) == "Yearly · renews Oct 14, 2027")
    }

    @Test func cancelledPlanSaysWhenItEndsAndDropsTheYearInTheSameYear() {
        let plan = ActivePlan(source: .appStore, period: .month, periodEnd: date(2026, 11, 2), isTrial: false, willRenew: false)
        #expect(plan.summary(locale: us, calendar: calendar, now: date(2026, 10, 11)) == "Monthly · ends Nov 2")
    }

    @Test func trialSaysWhatComesNext() {
        let renewing = ActivePlan(source: .appStore, period: .year, periodEnd: date(2026, 10, 14), isTrial: true, willRenew: true)
        let cancelled = ActivePlan(source: .appStore, period: .year, periodEnd: date(2026, 10, 14), isTrial: true, willRenew: false)
        #expect(renewing.summary(locale: us, calendar: calendar, now: date(2026, 10, 11)) == "Free trial · then yearly from Oct 14")
        #expect(cancelled.summary(locale: us, calendar: calendar, now: date(2026, 10, 11)) == "Free trial · ends Oct 14")
    }

    @Test func whereItsBilledFollowsTheSource() {
        #expect(ActivePlan(source: .web, period: .week, periodEnd: .now, isTrial: false, willRenew: true).manageHint == "Billed on the web")
        #expect(ActivePlan(source: .appStore, period: .week, periodEnd: .now, isTrial: false, willRenew: true).manageHint == "Billed by Apple")
    }
}
