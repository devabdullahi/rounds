import AppIntents

/// "What's my streak in Rounds": the streak and how long is left to keep it, read out.
struct StreakIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Streak"
    static let description = IntentDescription("Tells you your streak and how long is left to keep it.")

    @Dependency private var app: AppState

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard IntentSupport.isSignedIn else { return .result(dialog: IntentSupport.signInFirst) }
        await app.refresh()
        guard app.streak > 0, let left = app.streakTimeLeft else {
            return .result(dialog: "No streak right now. Finish a case to start one.")
        }
        return .result(dialog: "\(Streak.daysText(app.streak)). \(Streak.timeLeftText(left)).")
    }
}
