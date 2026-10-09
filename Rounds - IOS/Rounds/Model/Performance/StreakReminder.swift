import Foundation

/// A nudge before a streak lapses: when to send it and the streak it would save.
struct StreakReminder: Equatable, Sendable {
    let fireAt: Date
    let days: Int

    /// How long before the reset the reminder lands: late enough to be needed, early enough to act on.
    static let lead: TimeInterval = 2 * 60 * 60

    var title: String { "Keep your \(days)-day streak" }
    var body: String { "It resets in 2 hours. One case keeps it going." }

    /// The reminder for this streak, or nil when there's no streak or it's already inside the last
    /// two hours (a reminder then would arrive too late to be fair, or at once).
    static func plan(days: Int, timeLeft: TimeInterval?, now: Date = .now) -> StreakReminder? {
        guard days > 0, let timeLeft, timeLeft > lead else { return nil }
        return StreakReminder(fireAt: now.addingTimeInterval(timeLeft - lead), days: days)
    }
}
