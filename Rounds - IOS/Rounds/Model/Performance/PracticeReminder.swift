import Foundation

/// The daily practice nudge a student picks during onboarding: one local notification a day at a
/// time of their choosing. Separate from the streak reminder, which only fires to save a streak.
enum PracticeReminder: String, CaseIterable, Identifiable, Sendable {
    case morning, lunch, evening

    static let storageKey = "practiceReminder"

    var id: String { rawValue }

    /// Hour and minute of the day it fires, in the device's time zone.
    var time: (hour: Int, minute: Int) {
        switch self {
        case .morning: (8, 0)
        case .lunch: (12, 30)
        case .evening: (19, 0)
        }
    }

    var label: String {
        switch self {
        case .morning: "8:00 AM"
        case .lunch: "12:30 PM"
        case .evening: "7:00 PM"
        }
    }

    /// What the time of day is called on its chip.
    var period: String {
        switch self {
        case .morning: "Morning"
        case .lunch: "Lunch"
        case .evening: "Evening"
        }
    }

    var title: String { "Your patient is waiting" }
    var body: String { "One case today keeps your history-taking sharp." }

    /// Reads the stored raw value; nil when nothing (or something unknown) was saved.
    init?(stored: String) { self.init(rawValue: stored) }
}
