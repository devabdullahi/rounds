import Foundation
import Testing
@testable import Rounds

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func graded(_ id: String, daysAgo: Double, score: Int = 70, correct: Bool = true, missed: Int = 0,
                    clerkship: Clerkship? = .internalMedicine, system: OrganSystem? = .cardiovascular,
                    breakdown: [ScoreCategory: Points] = [:]) -> GradedCase {
    GradedCase(id: id, submittedAt: now.addingTimeInterval(-daysAgo * 86_400), score: score, diagnosisCorrect: correct,
               missedRedFlags: missed, clerkship: clerkship, system: system, breakdown: breakdown)
}

@Suite("Where you lose points")
struct PerformanceTests {
    private let recent = graded("a", daysAgo: 2, breakdown: [.history: Points(got: 10, max: 25), .exam: Points(got: 15, max: 15)])
    private let older = graded("b", daysAgo: 20, breakdown: [.history: Points(got: 25, max: 25), .exam: Points(got: 0, max: 15)])

    @Test func weakestShareComesFirst() {
        let (stats, cases) = Performance.stats([recent], in: .week, now: now)
        #expect(cases == 1)
        #expect(stats.map(\.category) == [.history, .exam])
        #expect(stats.first?.lost == 15)
    }

    @Test(arguments: [(Timeframe.week, 1), (.month, 2), (.all, 2)])
    func timeframeLimitsTheCases(timeframe: Timeframe, expected: Int) {
        #expect(Performance.stats([recent, older], in: timeframe, now: now).cases == expected)
    }

    @Test func totalsAddAcrossCases() {
        let history = Performance.stats([recent, older], in: .all, now: now).stats.first { $0.category == .history }
        #expect(history?.points == Points(got: 35, max: 50))
    }

    @Test func casesWithoutABreakdownAreLeftOut() {
        let (stats, cases) = Performance.stats([graded("old", daysAgo: 1)], in: .all, now: now)
        #expect(cases == 0)
        #expect(stats.isEmpty)
    }
}

@Suite("Badges")
struct BadgeTests {
    private func status(_ id: String, _ record: BadgeRecord) -> BadgeStatus? {
        BadgeCatalog.status(for: record).first { $0.badge.id == id }
    }

    @Test func everyoneHasBronzeAndNoOneStartsWithMore() {
        let fresh = BadgeRecord(rating: 1000, bestStreak: 0, cases: [])
        let unlocked = BadgeCatalog.status(for: fresh).filter(\.unlocked).map(\.badge.id)
        #expect(unlocked == ["bronze"])
    }

    @Test func lockedBadgesShowProgress() {
        let record = BadgeRecord(rating: 1000, bestStreak: 4, cases: [])
        let week = status("week-streak", record)
        #expect(week?.unlocked == false)
        #expect(week?.progressLabel == "4 / 7")
    }

    @Test func progressNeverPassesTheGoal() {
        let record = BadgeRecord(rating: 2500, bestStreak: 40, cases: [])
        #expect(status("gold", record)?.current == BadgeCatalog.goldRating)
        #expect(status("month-streak", record)?.unlocked == true)
    }

    @Test func hatTrickNeedsThreeCorrectInARow() {
        let mixed = [graded("1", daysAgo: 5), graded("2", daysAgo: 4), graded("3", daysAgo: 3, correct: false),
                     graded("4", daysAgo: 2), graded("5", daysAgo: 1)]
        #expect(BadgeCatalog.longestCorrectRun(mixed) == 2)
        #expect(BadgeCatalog.longestCorrectRun(mixed + [graded("6", daysAgo: 0)]) == 3)
    }

    @Test func newUnlocksSkipSeenOnesAndPlayRarestFirst() {
        let record = BadgeRecord(rating: 2100, bestStreak: 0, cases: [])
        let statuses = BadgeCatalog.status(for: record)
        let new = BadgeCatalog.newlyUnlocked(statuses, seen: ["bronze", "silver"])
        #expect(new.map(\.badge.id) == ["platinum", "gold"])
    }

    @Test func cardsKnowTheirPlaceInTheSet() {
        let record = BadgeRecord(rating: 1000, bestStreak: 0, cases: [])
        #expect(status("hat-trick", record)?.setNumber == "SKL 04/04")
        #expect(status("bronze", record)?.setNumber == "TIER 01/04")
    }

    @Test func smallCardsShowBigGoalsAsAPercentage() {
        let record = BadgeRecord(rating: 1482, bestStreak: 4, cases: [])
        #expect(status("gold", record)?.compactProgressLabel == "92%")
        #expect(status("week-streak", record)?.compactProgressLabel == "4/7")
    }

    @Test func aTestUnlockShowsTheCardAsEarned() {
        let locked = status("perfect", BadgeRecord(rating: 1000, bestStreak: 0, cases: []))
        #expect(locked?.unlocked == false)
        #expect(locked?.asUnlocked().unlocked == true)
    }

    @Test func rangeCountsDistinctRotations() {
        let cases = [graded("1", daysAgo: 1, clerkship: .surgery), graded("2", daysAgo: 1, clerkship: .surgery),
                     graded("3", daysAgo: 1, clerkship: .pediatrics)]
        #expect(status("rotation-tour", BadgeRecord(rating: 1000, bestStreak: 0, cases: cases))?.current == 2)
    }
}
