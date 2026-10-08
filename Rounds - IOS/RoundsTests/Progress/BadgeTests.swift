import Foundation
import Testing
@testable import Rounds

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
        // Platinum also completes the rating-tiers set; legendary cards play before the epic Gold.
        #expect(Set(new.prefix(2).map(\.badge.id)) == ["platinum", "set-tier"])
        #expect(new.last?.badge.id == "gold")
    }

    @Test func cardsKnowTheirPlaceInTheSet() {
        let record = BadgeRecord(rating: 1000, bestStreak: 0, cases: [])
        #expect(status("hat-trick", record)?.setNumber == "SKL 08/14")
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

    @Test func thereAre55CardsWithUniqueIDs() {
        #expect(BadgeCatalog.individual.count == 48)
        #expect(BadgeCatalog.all.count == 55)
        #expect(Set(BadgeCatalog.all.map(\.id)).count == 55)
        for group in Badge.Group.allCases {
            #expect(BadgeCatalog.all.contains { $0.group == group }, "\(group) has badges")
        }
    }

    @Test func fullMarksCountsOnlyCasesWithEveryPoint() {
        let full = GradedCase(id: "a", submittedAt: .now, score: 90, diagnosisCorrect: true, missedRedFlags: 0,
                              clerkship: nil, system: nil, breakdown: [.history: Points(got: 25, max: 25)])
        let partial = GradedCase(id: "b", submittedAt: .now, score: 70, diagnosisCorrect: true, missedRedFlags: 0,
                                 clerkship: nil, system: nil, breakdown: [.history: Points(got: 20, max: 25)])
        let none = GradedCase(id: "c", submittedAt: .now, score: 70, diagnosisCorrect: true, missedRedFlags: 0,
                              clerkship: nil, system: nil, breakdown: [:])
        #expect(BadgeCatalog.fullMarks(.history, in: [full, partial, none]) == 1)
    }

    @Test func nightAndMorningCasesCount() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago") ?? .gmt
        func at(_ hour: Int) -> GradedCase {
            let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: hour, minute: 30)) ?? .now
            return GradedCase(id: "\(hour)", submittedAt: date, score: 80, diagnosisCorrect: true, missedRedFlags: 0,
                              clerkship: nil, system: nil, breakdown: [:])
        }
        let cases = [at(23), at(6), at(12)]
        #expect(BadgeCatalog.finished(cases, hours: 22..<24, calendar: calendar) == 1)
        #expect(BadgeCatalog.finished(cases, hours: 4..<7, calendar: calendar) == 1)
    }

    @Test func specialistNeedsAnEightyAverageInOneRotation() {
        func c(_ clerkship: Clerkship, _ score: Int) -> GradedCase {
            GradedCase(id: UUID().uuidString, submittedAt: .now, score: score, diagnosisCorrect: true, missedRedFlags: 0,
                       clerkship: clerkship, system: nil, breakdown: [:])
        }
        let strong = (0..<4).map { _ in c(.pediatrics, 90) }
        let weak = (0..<6).map { _ in c(.surgery, 60) }
        #expect(BadgeCatalog.specialistCases(strong + weak) == 4)
    }

    @Test func examBadgesReadExamModeAndTimers() {
        let exam = GradedCase(id: "e", submittedAt: .now, score: 88, diagnosisCorrect: true, missedRedFlags: 0,
                              clerkship: nil, system: nil, breakdown: [:], examMode: true, timed: true)
        let record = BadgeRecord(rating: 1000, bestStreak: 0, cases: [exam])
        #expect(status("no-hints", record)?.unlocked == true)
        #expect(status("beat-the-clock", record)?.unlocked == true)
        #expect(status("exam-ready", record)?.unlocked == true)
    }

    @Test func studyBadgesReadDecksAndKnownCards() {
        let record = BadgeRecord(rating: 1000, bestStreak: 0, cases: [], decksGenerated: 2, notesDecks: 1, missDecks: 0, cardsKnown: 40)
        #expect(status("first-deck", record)?.unlocked == true)
        #expect(status("note-taker", record)?.unlocked == true)
        #expect(status("learn-from-misses", record)?.unlocked == false)
        #expect(status("card-shark", record)?.progressLabel == "40 / 100")
    }

    @Test func noTwoCardsShareASymbol() {
        let art = BadgeCatalog.all.map(\.art)
        #expect(Set(art).count == art.count)
    }

    @Test func everyBadgeHasArtWithAnArtist() {
        for badge in BadgeCatalog.all { #expect(!badge.art.artist.isEmpty) }
        #expect(BadgeArt.credits == ["Carl Olsen", "Delapouite", "Lorc", "Lord Berandas", "Skoll"])
    }

    private func caseAt(_ daysAgo: Double, caseID: String = UUID().uuidString, correct: Bool = true, score: Int = 90) -> GradedCase {
        GradedCase(id: UUID().uuidString, submittedAt: .now.addingTimeInterval(-daysAgo * 86_400), score: score,
                   diagnosisCorrect: correct, missedRedFlags: 0, clerkship: nil, system: nil, breakdown: [:], caseID: caseID)
    }

    @Test func secretCardsStayHiddenUntilEarned() {
        let record = BadgeRecord(rating: 1000, bestStreak: 0, cases: [])
        let comeback = status("comeback", record)
        #expect(comeback?.hidden == true)
        #expect(comeback?.asUnlocked().hidden == false)
        #expect(BadgeCatalog.nearest(BadgeCatalog.status(for: record)).allSatisfy { !$0.badge.secret })
    }

    @Test func aComebackIsARightAnswerAfterAMissOnTheSamePatient() {
        let missed = caseAt(3, caseID: "p1", correct: false, score: 40)
        let later = caseAt(1, caseID: "p1", correct: true, score: 88)
        let other = caseAt(2, caseID: "p2", correct: true, score: 95)
        #expect(BadgeCatalog.comebacks([missed, later, other]) == 1)
        #expect(BadgeCatalog.comebacks([later, other]) == 0)
    }

    @Test func earnedDatesPointAtTheCaseThatDidIt() throws {
        let cases = (0..<12).map { caseAt(Double(12 - $0)) }   // oldest first, a day apart
        let ten = try #require(status("ten-patients", BadgeRecord(rating: 1000, bestStreak: 0, cases: cases)))
        let tenth = cases.sorted { $0.submittedAt < $1.submittedAt }[9].submittedAt
        #expect(ten.earnedAt == tenth)
        #expect(status("silver", BadgeRecord(rating: 1300, bestStreak: 0, cases: cases))?.earnedAt == nil)
    }

    @Test func nudgesSayWhatIsLeft() {
        let record = BadgeRecord(rating: 1482, bestStreak: 5, cases: [caseAt(1), caseAt(2)])
        #expect(status("gold", record)?.nudge == "118 rating points to Gold")
        #expect(status("week-streak", record)?.nudge == "2 more days for Week streak")
        #expect(status("hat-trick", record)?.nudge == "1 more for Hat trick")
        #expect(status("ten-patients", record)?.toGoLabel == "8 to go")
    }

    @Test func theClosestCardsComeFirst() {
        let record = BadgeRecord(rating: 1000, bestStreak: 6, cases: [caseAt(1), caseAt(2)])
        let near = BadgeCatalog.nearest(BadgeCatalog.status(for: record))
        #expect(near.first?.badge.id == "week-streak")
        #expect(near.filter { $0.badge.group == .tier }.map(\.badge.id) == ["silver"])
    }

    @Test func aSetCardNeedsEveryCardInItsGroup() {
        let record = BadgeRecord(rating: 2100, bestStreak: 0, cases: [])
        #expect(status("set-tier", record)?.unlocked == true)
        #expect(status("set-volume", record)?.unlocked == false)
    }

    @Test func commonCardsOutnumberRareOnesAndSoOn() {
        let count = { (r: Badge.Rarity) in BadgeCatalog.all.filter { $0.rarity == r }.count }
        #expect(count(.common) > count(.rare))
        #expect(count(.rare) > count(.epic))
        #expect(count(.epic) > count(.legendary))
    }

    @Test func aSetIsAsRareAsItsHardestCard() {
        let rarity = { (id: String) in BadgeCatalog.all.first { $0.id == id }?.rarity }
        #expect(rarity("set-study") == .rare)
        #expect(rarity("set-tier") == .legendary)
    }

    @Test func practiceDaysAndWeekendsCount() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago") ?? .gmt
        func on(_ day: Int) -> GradedCase {   // Oct 2026: the 10th is a Saturday
            let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: 12)) ?? .now
            return GradedCase(id: "\(day)", submittedAt: date, score: 80, diagnosisCorrect: true, missedRedFlags: 0,
                              clerkship: nil, system: nil, breakdown: [:])
        }
        #expect(BadgeCatalog.practiceDays([on(8), on(8), on(9)], calendar: calendar) == 2)
        #expect(BadgeCatalog.weekendCases([on(9), on(10), on(11)], calendar: calendar) == 2)
    }
}
