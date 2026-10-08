import AppIntents

/// The phrases Siri knows without any setup. Apple requires the app's name in each one, and at
/// most one parameter per phrase.
struct RoundsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartPatientIntent(), phrases: [
            "Start my next patient in \(.applicationName)",
            "Next patient in \(.applicationName)",
            "Generate my next patient in \(.applicationName)",
            "Start a \(\.$topic) patient in \(.applicationName)",
            "Give me a \(\.$topic) patient in \(.applicationName)",
        ], shortTitle: "Next Patient", systemImageName: "stethoscope")
        AppShortcut(intent: QueuePatientIntent(), phrases: [
            "Queue my next patient in \(.applicationName)",
            "Queue a patient in \(.applicationName)",
            "Queue a \(\.$topic) patient in \(.applicationName)",
        ], shortTitle: "Queue Patient", systemImageName: "bed.double")
        AppShortcut(intent: MakeCardsIntent(), phrases: [
            "Make flashcards in \(.applicationName)",
            "Generate my cards in \(.applicationName)",
            "Make \(\.$topic) cards in \(.applicationName)",
            "Make \(\.$topic) flashcards in \(.applicationName)",
        ], shortTitle: "Make Flashcards", systemImageName: "rectangle.stack")
        AppShortcut(intent: ReviewMistakesIntent(), phrases: [
            "Review my mistakes in \(.applicationName)",
            "Make cards from my mistakes in \(.applicationName)",
        ], shortTitle: "Review Mistakes", systemImageName: "arrow.uturn.backward")
        AppShortcut(intent: StreakIntent(), phrases: [
            "What's my streak in \(.applicationName)",
            "Check my \(.applicationName) streak",
        ], shortTitle: "Streak", systemImageName: "flame")
    }
}
