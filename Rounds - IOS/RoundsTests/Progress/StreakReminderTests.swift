import Foundation
import Testing
@testable import Rounds

@Suite("Streak reminder")
struct StreakReminderTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func landsTwoHoursBeforeTheReset() {
        let reminder = StreakReminder.plan(days: 14, timeLeft: 10 * 3600, now: now)
        #expect(reminder?.fireAt == now.addingTimeInterval(8 * 3600))
        #expect(reminder?.title == "Keep your 14-day streak")
    }

    @Test(arguments: [(0, 10.0 * 3600), (5, 2.0 * 3600), (5, 3600)])
    func noReminderWithoutTimeToAct(days: Int, left: TimeInterval) {
        #expect(StreakReminder.plan(days: days, timeLeft: left, now: now) == nil)
    }

    @Test func noReminderWithoutAStreak() {
        #expect(StreakReminder.plan(days: 3, timeLeft: nil, now: now) == nil)
    }
}
