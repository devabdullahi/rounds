import AppIntents

/// "Start my next patient in Rounds": admits a patient for the student's focus (or the topic they
/// name) and opens the case. The app comes forward, since a case is interactive.
struct StartPatientIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Next Patient"
    static let description = IntentDescription("Admits a new fictional patient and opens the case.")
    static let openAppWhenRun = true

    @Parameter(title: "Topic", description: "A rotation or organ system. Leave empty for your saved focus.")
    var topic: IntentTopic?

    @Dependency private var app: AppState

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard IntentSupport.isSignedIn else { return .result(dialog: IntentSupport.signInFirst) }
        // A case already open is the next patient; don't stack another on top.
        guard app.activeCase == nil else { return .result(dialog: "Your current patient is still waiting.") }
        let focus = IntentSupport.focus(topic)
        app.showTodayRequested = true
        // Admitting can take minutes for a new topic; the Today tab shows the progress, so Siri
        // doesn't wait on it.
        Task { await app.admit(focus: focus) }
        return .result(dialog: focus.isMix ? "Admitting your next patient." : "Admitting a patient from \(focus.label).")
    }
}
