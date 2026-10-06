import Foundation

/// The rule behind onboarding's hold-to-promise heart: holding fills it, letting go drains it
/// faster than it filled, and a full heart locks in. A plain value type so the timing is
/// testable without a simulator; the view only feeds it elapsed time.
struct HoldToCommit: Equatable {
    /// Seconds of holding from empty to full.
    static let fillSeconds = 1.6
    /// Seconds to drain from full to empty after letting go.
    static let drainSeconds = 0.4

    private(set) var progress: Double = 0
    private(set) var isDone = false

    /// Moves the fill on by `seconds`. Returns true on the step that completes it.
    @discardableResult
    mutating func advance(by seconds: Double, holding: Bool) -> Bool {
        guard !isDone, seconds > 0 else { return false }
        let rate = holding ? 1 / Self.fillSeconds : -1 / Self.drainSeconds
        progress = min(1, max(0, progress + rate * seconds))
        if progress >= 1 { isDone = true; return true }
        return false
    }

    /// Nothing left to animate: full, or empty and not held.
    func isSettled(holding: Bool) -> Bool { isDone || (!holding && progress == 0) }

    /// Completes at once, for VoiceOver's activate action where holding isn't practical.
    mutating func complete() {
        progress = 1
        isDone = true
    }

    /// Quarter marks reached so far (0–4), so the view can tick a haptic at each one.
    var quarter: Int { Int(progress * 4) }
}
