import Foundation

enum BadgeCatalog {
    /// Rating floors for the tier badges; `RatingTier` names the profile's bands after them.
    /// Every account starts at the resident floor (1200), so Silver sits above it: earned, not given.
    static let silverRating = 1300
    static let goldRating = 1600
    static let platinumRating = 2000

    /// Every badge: the individual ones, then a set card per group that completes when the whole group does.
    static let all: [Badge] = individual + setCards

    /// The individual badges, with their achievement lines and secret flags filled in.
    static let individual: [Badge] = base.map { badge in
        var badge = badge
        badge.achieved = achieved[badge.id] ?? badge.detail
        badge.secret = secretIDs.contains(badge.id)
        return badge
    }

    /// Hidden until earned (a surprise when they land).
    static let secretIDs: Set<String> = ["night-shift", "early-rounds", "comeback"]

    /// What the student did, said as a clinical accomplishment once the card is earned.
    static let achieved: [String: String] = [
        "silver": "Reached a \(silverRating) rating.",
        "gold": "Reached a \(goldRating) rating.",
        "platinum": "Reached a \(platinumRating) rating. Top of the ward.",
        "first-patient": "Saw your first patient through to a diagnosis.",
        "ten-patients": "Worked up 10 patients.",
        "fifty-patients": "Worked up 50 patients.",
        "full-census": "Worked up 100 patients.",
        "textbook": "Scored 85+ with the right diagnosis.",
        "hat-trick": "Made 3 right diagnoses in a row.",
        "sharp-history": "Took a complete history on 10 patients.",
        "lean-workup": "Ordered only what mattered on 10 workups.",
        "on-a-roll": "Made 5 right diagnoses in a row.",
        "red-flag-hunter": "Caught every can't-miss condition on 10 patients.",
        "safety-net": "Screened every red flag on 25 patients.",
        "perfect": "Scored a perfect 100.",
        "warming-up": "Practiced 3 days running.",
        "night-shift": "Finished a case after 10 pm.",
        "early-rounds": "Finished a case before 7 am.",
        "week-streak": "Practiced 7 days running.",
        "two-weeks": "Practiced 14 days running.",
        "month-streak": "Practiced 30 days running.",
        "hundred-days": "Practiced 100 days running.",
        "explorer": "Worked in 5 different rotations.",
        "rotation-tour": "Worked in every rotation.",
        "specialist": "Averaged 80+ over 10 cases in one rotation.",
        "systems-check": "Saw a case in every organ system.",
        "comeback": "Came back to a patient you'd missed and got it right.",
        "five-patients": "Worked up 5 patients.",
        "right-call": "Made your first right diagnosis.",
        "solid-score": "Scored 70+ on a case.",
        "all-clear": "Screened every red flag on a case.",
        "full-history": "Took a complete history.",
        "clean-workup": "Ordered only the tests that mattered.",
        "double": "Made 2 right diagnoses in a row.",
        "back-again": "Came back for a second day.",
        "weekend-rounds": "Practiced on a weekend.",
        "second-rotation": "Worked in a second rotation.",
        "body-tour": "Saw cases in 3 organ systems.",
        "ten-known": "Knew 10 flashcards.",
        "on-the-clock": "Finished a case against the clock.",
        "first-deck": "Built your first flashcard deck.",
        "note-taker": "Turned your own notes into a deck.",
        "learn-from-misses": "Turned your mistakes into a deck.",
        "card-shark": "Knew 100 flashcards.",
        "no-hints": "Finished a case with no hints.",
        "beat-the-clock": "Got the diagnosis right against the clock.",
        "exam-ready": "Scored 85+ in exam mode.",
    ]

    /// One card per group, earned when every badge in it is, as rare as the group's hardest card.
    static let setCards: [Badge] = Badge.Group.allCases.filter { $0 != .sets }.map { group in
        let members = base.filter { $0.group == group }
        return Badge(id: "set-\(group.rawValue)", name: "\(group.label) set", detail: "Earn every \(group.label.lowercased()) card.",
                     art: setArt[group] ?? .crown, group: .sets, rarity: members.map(\.rarity).max() ?? .rare, goal: members.count,
                     measure: { record in members.filter { $0.measure(record) >= $0.goal }.count },
                     achieved: "Completed the \(group.label.lowercased()) set.")
    }

    /// Each set card's own art, so no two cards share a symbol.
    private static let setArt: [Badge.Group: BadgeArt] = [
        .tier: .crown, .volume: .trophyCup, .skill: .laurelsTrophy, .habit: .mountaintop,
        .range: .summits, .study: .bookPile, .exam: .diamondTrophy,
    ]

    private static let base: [Badge] = [
        // Rating tiers
        Badge(id: "silver", name: "Silver", detail: "Reach a \(silverRating) rating.", art: .podiumSecond,
              group: .tier, rarity: .rare, goal: silverRating, measure: { $0.rating }),
        Badge(id: "gold", name: "Gold", detail: "Reach a \(goldRating) rating.", art: .podiumWinner,
              group: .tier, rarity: .epic, goal: goldRating, measure: { $0.rating }),
        Badge(id: "platinum", name: "Platinum", detail: "Reach a \(platinumRating) rating. The top of the ward.", art: .jewelCrown,
              group: .tier, rarity: .legendary, goal: platinumRating, measure: { $0.rating }),

        // Patients seen
        Badge(id: "first-patient", name: "First patient", detail: "Finish your first case.", art: .stethoscope,
              group: .volume, rarity: .common, goal: 1, measure: { $0.cases.count }),
        Badge(id: "five-patients", name: "Five patients", detail: "Finish 5 cases.", art: .hospital,
              group: .volume, rarity: .common, goal: 5, measure: { $0.cases.count }),
        Badge(id: "ten-patients", name: "Ten patients", detail: "Finish 10 cases.", art: .personInBed,
              group: .volume, rarity: .common, goal: 10, measure: { $0.cases.count }),
        Badge(id: "fifty-patients", name: "Fifty patients", detail: "Finish 50 cases.", art: .threeFriends,
              group: .volume, rarity: .rare, goal: 50, measure: { $0.cases.count }),
        Badge(id: "full-census", name: "Full census", detail: "Finish 100 cases.", art: .hospitalCross,
              group: .volume, rarity: .epic, goal: 100, measure: { $0.cases.count }),

        // Clinical skill
        Badge(id: "right-call", name: "Right call", detail: "Get a diagnosis right.", art: .onTarget,
              group: .skill, rarity: .common, goal: 1, measure: { $0.cases.filter(\.diagnosisCorrect).count }),
        Badge(id: "solid-score", name: "Solid score", detail: "Score 70 or more on a case.", art: .thumbUp,
              group: .skill, rarity: .common, goal: 1, measure: { $0.cases.filter { $0.score >= 70 }.count }),
        Badge(id: "all-clear", name: "All clear", detail: "Finish a case without missing a red flag.", art: .checklist,
              group: .skill, rarity: .common, goal: 1, measure: { $0.cases.filter { $0.missedRedFlags == 0 }.count }),
        Badge(id: "full-history", name: "Full history", detail: "Uncover every key history point on a case.", art: .notebook,
              group: .skill, rarity: .common, goal: 1, measure: { fullMarks(.history, in: $0.cases) }),
        Badge(id: "clean-workup", name: "Clean workup", detail: "Order only the tests that matter on a case.", art: .testTubes,
              group: .skill, rarity: .common, goal: 1, measure: { fullMarks(.tests, in: $0.cases) }),
        Badge(id: "double", name: "Double", detail: "Get 2 diagnoses right in a row.", art: .doubleShot,
              group: .skill, rarity: .common, goal: 2, measure: { longestCorrectRun($0.cases) }),
        Badge(id: "textbook", name: "Textbook workup", detail: "Score 85 or more with the right diagnosis.", art: .ruleBook,
              group: .skill, rarity: .common, goal: 1, measure: { $0.cases.filter { $0.diagnosisCorrect && $0.score >= 85 }.count }),
        Badge(id: "hat-trick", name: "Hat trick", detail: "Get 3 diagnoses right in a row.", art: .targetArrows,
              group: .skill, rarity: .rare, goal: 3, measure: { longestCorrectRun($0.cases) }),
        Badge(id: "sharp-history", name: "Sharp history", detail: "Uncover every key history point on 10 cases.", art: .magnifyingGlass,
              group: .skill, rarity: .rare, goal: 10, measure: { fullMarks(.history, in: $0.cases) }),
        Badge(id: "lean-workup", name: "Lean workup", detail: "Order only the tests that matter on 10 cases.", art: .microscope,
              group: .skill, rarity: .rare, goal: 10, measure: { fullMarks(.tests, in: $0.cases) }),
        Badge(id: "on-a-roll", name: "On a roll", detail: "Get 5 diagnoses right in a row.", art: .focusedLightning,
              group: .skill, rarity: .epic, goal: 5, measure: { longestCorrectRun($0.cases) }),
        Badge(id: "red-flag-hunter", name: "Red-flag hunter", detail: "Finish 10 cases without missing a can't-miss condition.", art: .siren,
              group: .skill, rarity: .rare, goal: 10, measure: { $0.cases.filter { $0.missedRedFlags == 0 }.count }),
        Badge(id: "safety-net", name: "Safety net", detail: "Screen for every red flag on 25 cases.", art: .healingShield,
              group: .skill, rarity: .epic, goal: 25, measure: { $0.cases.filter { $0.missedRedFlags == 0 }.count }),
        Badge(id: "perfect", name: "Perfect score", detail: "Score 100 on a case.", art: .laurelCrown,
              group: .skill, rarity: .legendary, goal: 1, measure: { $0.cases.filter { $0.score >= 100 }.count }),

        // Habits
        Badge(id: "warming-up", name: "Warming up", detail: "Keep a 3-day streak.", art: .flame,
              group: .habit, rarity: .common, goal: 3, measure: { $0.bestStreak }),
        Badge(id: "back-again", name: "Back again", detail: "Practice on 2 different days.", art: .calendar,
              group: .habit, rarity: .common, goal: 2, measure: { practiceDays($0.cases) }),
        Badge(id: "weekend-rounds", name: "Weekend rounds", detail: "Finish a case on a Saturday or Sunday.", art: .sunset,
              group: .habit, rarity: .common, goal: 1, measure: { weekendCases($0.cases) }),
        Badge(id: "night-shift", name: "Night shift", detail: "Finish a case after 10 pm.", art: .nightSky,
              group: .habit, rarity: .common, goal: 1, measure: { finished($0.cases, hours: 22..<24) }),
        Badge(id: "early-rounds", name: "Early rounds", detail: "Finish a case before 7 am.", art: .sunrise,
              group: .habit, rarity: .common, goal: 1, measure: { finished($0.cases, hours: 4..<7) }),
        Badge(id: "week-streak", name: "Week streak", detail: "Keep a 7-day streak.", art: .fluffyFlame,
              group: .habit, rarity: .common, goal: 7, measure: { $0.bestStreak }),
        Badge(id: "two-weeks", name: "Two weeks", detail: "Keep a 14-day streak.", art: .fireGem,
              group: .habit, rarity: .rare, goal: 14, measure: { $0.bestStreak }),
        Badge(id: "month-streak", name: "Month streak", detail: "Keep a 30-day streak.", art: .flameSpin,
              group: .habit, rarity: .epic, goal: 30, measure: { $0.bestStreak }),
        Badge(id: "hundred-days", name: "Hundred days", detail: "Keep a 100-day streak.", art: .trophy,
              group: .habit, rarity: .legendary, goal: 100, measure: { $0.bestStreak }),

        // Range
        Badge(id: "second-rotation", name: "Second rotation", detail: "Finish cases in 2 different rotations.", art: .flagObjective,
              group: .range, rarity: .common, goal: 2, measure: { Set($0.cases.compactMap(\.clerkship)).count }),
        Badge(id: "body-tour", name: "Body tour", detail: "Finish cases in 3 organ systems.", art: .heartOrgan,
              group: .range, rarity: .common, goal: 3, measure: { Set($0.cases.compactMap(\.system)).count }),
        Badge(id: "explorer", name: "Explorer", detail: "Finish cases in 5 different rotations.", art: .compass,
              group: .range, rarity: .common, goal: 5, measure: { Set($0.cases.compactMap(\.clerkship)).count }),
        Badge(id: "rotation-tour", name: "Rotation tour", detail: "Finish a case in every rotation.", art: .treasureMap,
              group: .range, rarity: .rare, goal: Clerkship.allCases.count, measure: { Set($0.cases.compactMap(\.clerkship)).count }),
        Badge(id: "specialist", name: "Specialist", detail: "Finish 10 cases in one rotation, averaging 80 or more.", art: .targetPrize,
              group: .range, rarity: .epic, goal: 10, measure: { specialistCases($0.cases) }),
        Badge(id: "comeback", name: "Comeback", detail: "Score 85 or more on a patient you previously missed.", art: .returnArrow,
              group: .range, rarity: .rare, goal: 1, measure: { comebacks($0.cases) }),
        Badge(id: "systems-check", name: "Systems check", detail: "Finish a case in every organ system.", art: .dna,
              group: .range, rarity: .rare, goal: OrganSystem.allCases.count, measure: { Set($0.cases.compactMap(\.system)).count }),

        // Study
        Badge(id: "first-deck", name: "First deck", detail: "Generate your first flashcard deck.", art: .tiedScroll,
              group: .study, rarity: .common, goal: 1, measure: { $0.decksGenerated }),
        Badge(id: "note-taker", name: "Note taker", detail: "Make a deck from your own notes.", art: .scrollQuill,
              group: .study, rarity: .common, goal: 1, measure: { $0.notesDecks }),
        Badge(id: "learn-from-misses", name: "Learn from misses", detail: "Make a deck from your mistakes.", art: .eyeTarget,
              group: .study, rarity: .common, goal: 1, measure: { $0.missDecks }),
        Badge(id: "ten-known", name: "Ten known", detail: "Mark 10 flashcards as known.", art: .upCard,
              group: .study, rarity: .common, goal: 10, measure: { $0.cardsKnown }),
        Badge(id: "card-shark", name: "Card shark", detail: "Mark 100 flashcards as known.", art: .brainstorm,
              group: .study, rarity: .rare, goal: 100, measure: { $0.cardsKnown }),

        // Exam mode
        Badge(id: "on-the-clock", name: "On the clock", detail: "Finish a case with a time limit on.", art: .hourglass,
              group: .exam, rarity: .common, goal: 1, measure: { $0.cases.filter(\.timed).count }),
        Badge(id: "no-hints", name: "No hints", detail: "Finish a case in exam mode.", art: .nightVision,
              group: .exam, rarity: .common, goal: 1, measure: { $0.cases.filter(\.examMode).count }),
        Badge(id: "beat-the-clock", name: "Beat the clock", detail: "Get the diagnosis right with a time limit on.", art: .stopwatch,
              group: .exam, rarity: .common, goal: 1, measure: { $0.cases.filter { $0.timed && $0.diagnosisCorrect }.count }),
        Badge(id: "exam-ready", name: "Exam ready", detail: "Score 85 or more in exam mode.", art: .starMedal,
              group: .exam, rarity: .rare, goal: 1, measure: { $0.cases.filter { $0.examMode && $0.score >= 85 }.count }),
    ]

    static func status(for record: BadgeRecord) -> [BadgeStatus] {
        let chronological = record.cases.sorted { $0.submittedAt < $1.submittedAt }
        return all.map { badge in
            let set = all.filter { $0.group == badge.group }
            let index = (set.firstIndex { $0.id == badge.id } ?? 0) + 1
            let number = "\(badge.group.code) " + String(format: "%02d/%02d", index, set.count)
            let current = min(badge.measure(record), badge.goal)
            let earnedAt = current >= badge.goal && badge.datedByCases ? earnedDate(badge, record, chronological) : nil
            return BadgeStatus(badge: badge, current: current, setNumber: number, earnedAt: earnedAt)
        }
    }

    /// The case that first met the badge's goal: the shortest run of cases, in order, that earns
    /// it. Binary search, since adding cases never takes a case-based badge away.
    static func earnedDate(_ badge: Badge, _ record: BadgeRecord, _ chronological: [GradedCase]) -> Date? {
        func earned(after count: Int) -> Bool {
            var prefix = record
            prefix.cases = Array(chronological.prefix(count))
            prefix.bestStreak = Streak.best(prefix.cases.map(\.submittedAt))
            return badge.measure(prefix) >= badge.goal
        }
        guard !chronological.isEmpty, earned(after: chronological.count) else { return nil }
        var low = 1, high = chronological.count
        while low < high {
            let mid = (low + high) / 2
            if earned(after: mid) { high = mid } else { low = mid + 1 }
        }
        return chronological[low - 1].submittedAt
    }

    /// Locked cards closest to done, for "almost there" nudges: visible ones with some progress,
    /// furthest along first.
    static func nearest(_ statuses: [BadgeStatus], limit: Int = 3) -> [BadgeStatus] {
        // Ratings count from zero, so only the next tier is a real target; a set card only when one card is left.
        let nextTier = statuses.first { $0.badge.group == .tier && !$0.unlocked }?.id
        return statuses
            .filter { !$0.unlocked && !$0.badge.secret && $0.current > 0 }
            .filter { $0.badge.group != .tier || $0.id == nextTier }
            .filter { $0.badge.group != .sets || $0.remaining == 1 }
            .sorted { ($0.progress, -$0.remaining) > ($1.progress, -$1.remaining) }
            .prefix(limit)
            .map { $0 }
    }

    /// Times a patient was got right (85+) after an earlier miss on the same patient.
    static func comebacks(_ cases: [GradedCase]) -> Int {
        Dictionary(grouping: cases.filter { $0.caseID != nil }, by: \.caseID).values.reduce(0) { total, attempts in
            let ordered = attempts.sorted { $0.submittedAt < $1.submittedAt }
            guard let firstMiss = ordered.firstIndex(where: { !$0.diagnosisCorrect }) else { return total }
            return total + ordered[(firstMiss + 1)...].filter { $0.diagnosisCorrect && $0.score >= 85 }.count
        }
    }

    /// Unlocked badges the student hasn't been shown yet, rarest first so the biggest moment
    /// plays first when several land at once.
    static func newlyUnlocked(_ statuses: [BadgeStatus], seen: Set<String>) -> [BadgeStatus] {
        statuses.filter { $0.unlocked && !seen.contains($0.id) }
            .sorted { $0.badge.rarity > $1.badge.rarity }
    }

    /// Cases that earned every point in one part of the grade (cases without a breakdown don't count).
    static func fullMarks(_ part: ScoreCategory, in cases: [GradedCase]) -> Int {
        cases.filter { c in c.breakdown[part].map { $0.max > 0 && $0.got >= $0.max } ?? false }.count
    }

    /// Cases finished in an hour range of the student's own day (22..<24 is 10 pm to midnight).
    static func finished(_ cases: [GradedCase], hours: Range<Int>, calendar: Calendar = .current) -> Int {
        cases.filter { hours.contains(calendar.component(.hour, from: $0.submittedAt)) }.count
    }

    /// Distinct days with a graded case, in the student's calendar.
    static func practiceDays(_ cases: [GradedCase], calendar: Calendar = .current) -> Int {
        Set(cases.map { calendar.startOfDay(for: $0.submittedAt) }).count
    }

    /// Cases finished on a Saturday or Sunday.
    static func weekendCases(_ cases: [GradedCase], calendar: Calendar = .current) -> Int {
        cases.filter { calendar.isDateInWeekend($0.submittedAt) }.count
    }

    /// Most cases in a single rotation whose average score is 80 or more.
    static func specialistCases(_ cases: [GradedCase]) -> Int {
        Dictionary(grouping: cases.filter { $0.clerkship != nil }, by: \.clerkship)
            .values
            .filter { Double($0.reduce(0) { $0 + $1.score }) / Double(max(1, $0.count)) >= 80 }
            .map(\.count)
            .max() ?? 0
    }

    /// Longest run of correct diagnoses, in the order the cases were graded.
    static func longestCorrectRun(_ cases: [GradedCase]) -> Int {
        var best = 0, run = 0
        for c in cases.sorted(by: { $0.submittedAt < $1.submittedAt }) {
            run = c.diagnosisCorrect ? run + 1 : 0
            best = max(best, run)
        }
        return best
    }
}
