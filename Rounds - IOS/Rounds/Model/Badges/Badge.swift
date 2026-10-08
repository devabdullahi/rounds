import Foundation

/// An achievement, shown as a trading card. It measures one number from the record and unlocks at
/// `goal`, so a locked card can show how close the student is ("4 / 10").
struct Badge: Identifiable, Sendable {
    enum Group: String, CaseIterable, Sendable {
        case tier, volume, skill, habit, range
        var label: String {
            switch self {
            case .tier: "Rating tiers"
            case .volume: "Patients seen"
            case .skill: "Clinical skill"
            case .habit: "Daily habit"
            case .range: "Range"
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
    let glyph: IconGlyph
    let group: Group
    let rarity: Rarity
    let goal: Int
    let measure: @Sendable (BadgeRecord) -> Int
}
