import Foundation
import Testing
@testable import Rounds

/// "2 of 3 decks left today", and when that count stops applying.
struct DeckAllowanceTests {
    @Test(arguments: [(2, 3, "2 of 3 decks left today"), (0, 1, "0 of 1 deck left today")])
    func labelsReadNaturally(remaining: Int, limit: Int, label: String) {
        #expect(DeckAllowance(remaining: remaining, limit: limit).label == label)
    }

    @Test func aCountFromEarlierTodayStillApplies() throws {
        let morning = try #require(ISO8601DateFormatter().date(from: "2026-10-07T01:00:00Z"))
        let evening = try #require(ISO8601DateFormatter().date(from: "2026-10-07T23:00:00Z"))
        #expect(DeckAllowance(remaining: 2, limit: 3, asOf: morning).isCurrent(now: evening))
    }

    @Test func limitsResetAtMidnightUTC() throws {
        let lateNight = try #require(ISO8601DateFormatter().date(from: "2026-10-07T23:59:00Z"))
        let nextDay = try #require(ISO8601DateFormatter().date(from: "2026-10-08T00:01:00Z"))
        #expect(!DeckAllowance(remaining: 0, limit: 3, asOf: lateNight).isCurrent(now: nextDay))
    }
}
