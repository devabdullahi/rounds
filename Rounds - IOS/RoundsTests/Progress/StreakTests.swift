import Foundation
import Testing
@testable import Rounds

/// Streaks from graded cases: alive for 24 hours after each case, counted in days.
struct StreakTests {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Chicago") ?? .gmt
        return c
    }()
    /// Thursday 8 Oct 2026, 3 pm.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 15)) ?? .now }
    private func hoursAgo(_ h: Double) -> Date { now.addingTimeInterval(-h * 3600) }

    @Test func dailyCasesBuildTheStreak() {
        // Today 2 pm, yesterday 4 pm, the day before 5 pm: every gap under 24 h.
        #expect(Streak.current([hoursAgo(1), hoursAgo(23), hoursAgo(46)], now: now, calendar: calendar) == 3)
    }

    @Test func moreThan24HoursSinceTheLastCaseResets() {
        #expect(Streak.current([hoursAgo(25), hoursAgo(40)], now: now, calendar: calendar) == 0)
    }

    @Test func aStreakIsAliveWithin24Hours() {
        #expect(Streak.current([hoursAgo(23)], now: now, calendar: calendar) == 1)
    }

    @Test func aGapOfMoreThan24HoursBetweenCasesBreaksTheRun() {
        // Latest run: today and yesterday; a 30-hour gap before that.
        #expect(Streak.current([hoursAgo(2), hoursAgo(20), hoursAgo(50), hoursAgo(60)], now: now, calendar: calendar) == 2)
    }

    @Test func severalCasesInADayCountOnce() {
        #expect(Streak.current([hoursAgo(1), hoursAgo(3), hoursAgo(5)], now: now, calendar: calendar) == 1)
    }

    @Test func noCasesMeansNoStreak() {
        #expect(Streak.current([], now: now, calendar: calendar) == 0)
        #expect(Streak.best([], calendar: calendar) == 0)
    }

    @Test func bestIsTheLongestRunEver() {
        // An old 4-day run, a gap, then today's single day.
        let old = (0..<4).map { hoursAgo(200 + Double($0) * 20) }
        #expect(Streak.best(old + [hoursAgo(1)], calendar: calendar) == 4)
    }

    @Test(arguments: [(0, 0.0), (7, 1.0 / 3), (21, 1.0), (40, 1.0)])
    func theFlameGrowsUntilThreeWeeks(days: Int, heat: Double) {
        #expect(abs(Streak.heat(days) - heat) < 0.0001)
    }

    @Test @MainActor func everyWeekHasAColour() {
        #expect(Theme.streakWeeks.count == Streak.weekColorCount)
    }

    @Test(arguments: [(0, 0), (6, 0), (7, 1), (13, 1), (14, 2), (34, 4), (35, 0), (42, 1)])
    func colourStepsEverySevenDays(days: Int, index: Int) {
        #expect(Streak.weekColorIndex(days) == index)
    }
}
