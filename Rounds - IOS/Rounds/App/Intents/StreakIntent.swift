import AppIntents

/// "What's my streak in Rounds": the streak and how long is left to keep it, read out. It also
/// returns the day count, so a shortcut can act on it ("if my streak is 0, remind me").
struct StreakIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Streak"
    static let description = IntentDescription("Tells you your streak and how long is left to keep it.")

    @Dependency private var app: AppState

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        guard IntentSupport.isSignedIn else { return .result(value: 0, dialog: IntentSupport.signInFirst) }
        let (days, dialog) = await IntentActions.streak(app)
        return .result(value: days, dialog: dialog)
    }
}
