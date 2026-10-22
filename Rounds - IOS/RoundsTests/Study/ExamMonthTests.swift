import Foundation
import Testing
@testable import Rounds

/// The exam month: stored form, the months offered, and the countdown the plan is built on.
struct ExamMonthTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func storesAsYearAndMonth() {
        #expect(ExamMonth(year: 2026, month: 12).stored == "2026-12")
        #expect(ExamMonth(stored: "2027-01") == ExamMonth(year: 2027, month: 1))
        #expect(ExamMonth(stored: ExamMonth.later) == nil)
        #expect(ExamMonth(stored: "2026-13") == nil)
    }

    @Test func offersFiveMonthsAcrossTheYearEnd() {
        let months = ExamMonth.upcoming(from: date(2026, 10, 22), calendar: calendar)
        #expect(months.map(\.stored) == ["2026-10", "2026-11", "2026-12", "2027-01", "2027-02"])
    }

    @Test func countsWeeksToMidMonthAndPatientsAtTheDailyPace() {
        let dec = ExamMonth(year: 2026, month: 12)
        // Oct 22 to Dec 15 is 54 days: 7 whole weeks.
        #expect(dec.weeksLeft(from: date(2026, 10, 22), calendar: calendar) == 7)
        #expect(dec.patients(perDay: 2, from: date(2026, 10, 22), calendar: calendar) == 98)
        // This month, past the middle: at least a week.
        #expect(ExamMonth(year: 2026, month: 10).weeksLeft(from: date(2026, 10, 22), calendar: calendar) == 1)
    }
}
