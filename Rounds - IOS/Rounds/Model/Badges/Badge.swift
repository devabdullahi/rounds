import Foundation

/// An achievement, shown as a trading card. It measures one number from the record and unlocks at
/// `goal`, so a locked card can show how close the student is ("4 / 10").
struct Badge: Identifiable, Sendable {
    enum Group: String, CaseIterable, Sendable {
        case tier, volume, skill, habit, range, study, exam, sets
        var label: String {
            switch self {
            case .tier: "Rating tiers"
            case .volume: "Patients seen"
            case .skill: "Clinical skill"
            case .habit: "Habits"
            case .range: "Range"
            case .study: "Study"
            case .exam: "Exam mode"
            case .sets: "Complete sets"
            }
        }
        /// Short set code printed on the card ("SKL 03/04").
        var code: String {
            switch self {
            case .tier: "TIER"
            case .volume: "VOL"
            case .skill: "SKL"
            case .habit: "HAB"
            case .range: "RNG"
            case .study: "STD"
            case .exam: "EXM"
            case .sets: "SET"
            }
        }
    }

    /// How hard the badge is to earn. Picks the card's ink and foil, and how big the unlock is.
    enum Rarity: Int, CaseIterable, Comparable, Sendable {
        case common, rare, epic, legendary
        var label: String {
            switch self {
            case .common: "Common"
            case .rare: "Rare"
            case .epic: "Epic"
            case .legendary: "Legendary"
            }
        }
        /// Rare and up carry holographic foil.
        var hasFoil: Bool { self != .common }
        static func < (a: Rarity, b: Rarity) -> Bool { a.rawValue < b.rawValue }
    }

    let id: String
    let name: String
    /// How to earn it, in the student's terms.
    let detail: String
    let art: BadgeArt
    let group: Group
    let rarity: Rarity
    let goal: Int
    let measure: @Sendable (BadgeRecord) -> Int
    /// What the student did, in clinical terms, shown once earned ("Screened every red flag on 25 cases").
    var achieved = ""
    /// Hidden until earned: shown as a "?" card, so earning it is a surprise.
    var secret = false

    /// Streak badges count days, which the nudge says in words.
    var measuresStreak: Bool { ["warming-up", "week-streak", "two-weeks", "month-streak", "hundred-days"].contains(id) }

    /// Whether this badge's progress comes from graded cases, so the day it was earned can be found.
    var datedByCases: Bool { ![.tier, .study, .sets].contains(group) }
}
