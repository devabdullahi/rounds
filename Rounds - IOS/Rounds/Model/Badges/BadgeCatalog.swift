import Foundation

enum BadgeCatalog {
    /// Rating floors for the tier badges (the identity card's "to Gold" uses the same Gold floor).
    static let silverRating = AppState.residentFloor
    static let goldRating = AppState.fellowThreshold
    static let platinumRating = 2000

    static let all: [Badge] = [
        Badge(id: "bronze", name: "Bronze", detail: "Every new student starts here.", glyph: .award,
              group: .tier, rarity: .common, goal: 1, measure: { _ in 1 }),
        Badge(id: "silver", name: "Silver", detail: "Reach a \(silverRating) rating.", glyph: .award,
              group: .tier, rarity: .rare, goal: silverRating, measure: { $0.rating }),
        Badge(id: "gold", name: "Gold", detail: "Reach a \(goldRating) rating.", glyph: .award,
              group: .tier, rarity: .epic, goal: goldRating, measure: { $0.rating }),
        Badge(id: "platinum", name: "Platinum", detail: "Reach a \(platinumRating) rating. The top of the ward.", glyph: .crown,
              group: .tier, rarity: .legendary, goal: platinumRating, measure: { $0.rating }),

        Badge(id: "first-patient", name: "First patient", detail: "Finish your first case.", glyph: .stethoscope,
              group: .volume, rarity: .common, goal: 1, measure: { $0.cases.count }),
        Badge(id: "ten-patients", name: "Ten patients", detail: "Finish 10 cases.", glyph: .stethoscope,
              group: .volume, rarity: .rare, goal: 10, measure: { $0.cases.count }),
        Badge(id: "fifty-patients", name: "Fifty patients", detail: "Finish 50 cases.", glyph: .firstAid,
              group: .volume, rarity: .epic, goal: 50, measure: { $0.cases.count }),

        Badge(id: "textbook", name: "Textbook workup", detail: "Score 85 or more with the right diagnosis.", glyph: .sealCheck,
              group: .skill, rarity: .rare, goal: 1, measure: { $0.cases.filter { $0.diagnosisCorrect && $0.score >= 85 }.count }),
        Badge(id: "perfect", name: "Perfect score", detail: "Score 100 on a case.", glyph: .star,
              group: .skill, rarity: .legendary, goal: 1, measure: { $0.cases.filter { $0.score >= 100 }.count }),
        Badge(id: "red-flag-hunter", name: "Red-flag hunter", detail: "Finish 10 cases without missing a can't-miss condition.", glyph: .siren,
              group: .skill, rarity: .epic, goal: 10, measure: { $0.cases.filter { $0.missedRedFlags == 0 }.count }),
        Badge(id: "hat-trick", name: "Hat trick", detail: "Get 3 diagnoses right in a row.", glyph: .lightning,
              group: .skill, rarity: .rare, goal: 3, measure: { longestCorrectRun($0.cases) }),

        Badge(id: "week-streak", name: "Week streak", detail: "Practice 7 days in a row.", glyph: .flame,
              group: .habit, rarity: .rare, goal: 7, measure: { $0.bestStreak }),
        Badge(id: "month-streak", name: "Month streak", detail: "Practice 30 days in a row.", glyph: .calendarCheck,
              group: .habit, rarity: .epic, goal: 30, measure: { $0.bestStreak }),

        Badge(id: "rotation-tour", name: "Rotation tour", detail: "Finish a case in every rotation.", glyph: .compass,
              group: .range, rarity: .epic, goal: Clerkship.allCases.count, measure: { Set($0.cases.compactMap(\.clerkship)).count }),
        Badge(id: "systems-check", name: "Systems check", detail: "Finish a case in every organ system.", glyph: .heartbeat,
              group: .range, rarity: .legendary, goal: OrganSystem.allCases.count, measure: { Set($0.cases.compactMap(\.system)).count }),
    ]

    static func status(for record: BadgeRecord) -> [BadgeStatus] {
        all.map { badge in
            let set = all.filter { $0.group == badge.group }
            let index = (set.firstIndex { $0.id == badge.id } ?? 0) + 1
            let number = "\(badge.group.code) " + String(format: "%02d/%02d", index, set.count)
            return BadgeStatus(badge: badge, current: min(badge.measure(record), badge.goal), setNumber: number)
        }
    }

    /// Unlocked badges the student hasn't been shown yet, rarest first so the biggest moment
    /// plays first when several land at once.
    static func newlyUnlocked(_ statuses: [BadgeStatus], seen: Set<String>) -> [BadgeStatus] {
        statuses.filter { $0.unlocked && !seen.contains($0.id) }
            .sorted { $0.badge.rarity > $1.badge.rarity }
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
