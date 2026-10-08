import Foundation

/// Schedules the on-device streak reminder. A live version uses local notifications; tests and
/// previews pass none.
protocol ReminderService: Sendable {
    /// Asks once for permission to notify; later calls return the stored answer without a prompt.
    func requestPermission() async -> Bool
    /// Replaces any pending streak reminder with this one, or clears it when nil.
    func schedule(_ reminder: StreakReminder?) async
    /// Posts a notification now, for work that finished after Siri stopped waiting.
    func announce(title: String, body: String) async
}
