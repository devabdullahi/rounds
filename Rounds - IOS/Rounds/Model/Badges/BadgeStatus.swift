import Foundation

/// A badge against one student's record.
struct BadgeStatus: Identifiable, Sendable {
    let badge: Badge
    let current: Int
    /// "SKL 03/04": the card's place in its set.
    let setNumber: String
    /// When it was earned, where graded cases show it; nil for rating and study badges.
    var earnedAt: Date?
    var id: String { badge.id }
    /// Shown face down with no name or rule until earned.
    var hidden: Bool { badge.secret && !unlocked }
    /// Steps left to the goal.
    var remaining: Int { max(0, badge.goal - current) }
    /// The card back's label: "2 to go", or a percentage for big goals (ratings).
    var toGoLabel: String { badge.goal >= 1000 ? compactProgressLabel : "\(remaining) to go" }
    /// A nudge toward it: "118 rating points to Gold", "1 more for Hat trick".
    var nudge: String {
        switch badge.group {
        case .tier: "\(remaining) rating points to \(badge.name)"
        case .habit where badge.measuresStreak: "\(remaining) more \(remaining == 1 ? "day" : "days") for \(badge.name)"
        default: "\(remaining) more for \(badge.name)"
        }
    }
    var unlocked: Bool { current >= badge.goal }
    /// 0…1 toward the goal.
    var progress: Double { min(1, Double(current) / Double(max(1, badge.goal))) }
    /// "4 / 10" toward the goal.
    var progressLabel: String { "\(current.formatted()) / \(badge.goal.formatted())" }
    /// Fits a small card back: counts as "4/10", big goals (ratings) as a percentage, "93%".
    var compactProgressLabel: String {
        badge.goal >= 1000 ? "\(Int((progress * 100).rounded(.down)))%" : "\(current)/\(badge.goal)"
    }

    /// The same card as if just earned, for the unlock animation's test button.
    func asUnlocked() -> BadgeStatus { BadgeStatus(badge: badge, current: badge.goal, setNumber: setNumber, earnedAt: .now) }
}
