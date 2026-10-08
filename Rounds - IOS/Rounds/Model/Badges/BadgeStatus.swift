import Foundation

/// A badge against one student's record.
struct BadgeStatus: Identifiable, Sendable {
    let badge: Badge
    let current: Int
    /// "SKL 03/04": the card's place in its set.
    let setNumber: String
    var id: String { badge.id }
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
    func asUnlocked() -> BadgeStatus { BadgeStatus(badge: badge, current: badge.goal, setNumber: setNumber) }
}
