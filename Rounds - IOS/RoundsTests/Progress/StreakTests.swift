import Foundation
import Testing
@testable import Rounds

/// Streak days from graded cases, and the weekly colour step.
struct StreakTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago") ?? .gmt
        return c
    }()
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 15)) ?? .now }

    /// Noon `ago` days before today, so time zones can't shift the day.
    private func day(_ ago: Int, hour: Int = 12) -> Date {
        let today = calendar.startOfDay(for: now)
        let d = calendar.date(byAdding: .day, value: -ago, to: today) ?? today
        return calendar.date(byAdding: .hour, value: hour, to: d) ?? d
    }

    @Test func consecutiveDaysEndingTodayCount() {
        #expect(Streak.current([day(0), day(1), day(2)], now: now, calendar: calendar) == 3)
    }

    @Test func aStreakEndingYesterdayIsStillAlive() {
        #expect(Streak.current([day(1), day(2)], now: now, calendar: calendar) == 2)
    }

    @Test func aMissedDayEndsIt() {
        #expect(Streak.current([day(2), day(3)], now: now, calendar: calendar) == 0)
        #expect(Streak.current([day(0), day(2), day(3)], now: now, calendar: calendar) == 1)
    }

    @Test func severalCasesInADayCountOnce() {
        #expect(Streak.current([day(0, hour: 8), day(0, hour: 20), day(1)], now: now, calendar: calendar) == 2)
    }

    @Test func noCasesMeansNoStreak() {
        #expect(Streak.current([], now: now, calendar: calendar) == 0)
        #expect(Streak.best([], calendar: calendar) == 0)
    }

    @Test func bestIsTheLongestRunEver() {
        let dates = [day(0), day(1), day(10), day(11), day(12), day(13), day(20)]
        #expect(Streak.best(dates, calendar: calendar) == 4)
    }

    @Test @MainActor func everyWeekHasAColour() {
        #expect(Theme.streakWeeks.count == Streak.weekColorCount)
    }

    @Test(arguments: [(0, 0), (6, 0), (7, 1), (13, 1), (14, 2), (34, 4), (35, 0), (42, 1)])
    func colourStepsEverySevenDays(days: Int, index: Int) {
        #expect(Streak.weekColorIndex(days) == index)
    }
}
