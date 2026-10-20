import Testing
@testable import Rounds

struct PracticeReminderTests {
    @Test(arguments: PracticeReminder.allCases)
    func storedValueRoundTrips(reminder: PracticeReminder) {
        #expect(PracticeReminder(stored: reminder.rawValue) == reminder)
    }

    @Test func unknownStoredValueReadsAsNone() {
        #expect(PracticeReminder(stored: "") == nil)
        #expect(PracticeReminder(stored: "night") == nil)
    }

    /// The label on each chip matches the hour the notification is scheduled for.
    @Test(arguments: [(PracticeReminder.morning, 8, 0, "8:00 AM"), (.lunch, 12, 30, "12:30 PM"), (.evening, 19, 0, "7:00 PM")])
    func labelMatchesItsTime(reminder: PracticeReminder, hour: Int, minute: Int, label: String) {
        #expect(reminder.time.hour == hour)
        #expect(reminder.time.minute == minute)
        #expect(reminder.label == label)
    }
}
