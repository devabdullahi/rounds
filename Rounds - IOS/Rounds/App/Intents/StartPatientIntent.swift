import AppIntents

/// "Start my next patient in Rounds": admits a patient for the student's focus (or the topic they
/// name) and opens the case. The app comes forward, since a case is interactive.
struct StartPatientIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Next Patient"
    static let description = IntentDescription("Admits a new fictional patient and opens the case.")
    static let openAppWhenRun = true

    @Parameter(title: "Topic", description: "A specialty or organ system. Leave empty for your saved focus.")
    var topic: IntentTopic?

    @Dependency private var app: AppState

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard IntentSupport.isReady else { return .result(dialog: IntentSupport.openAppFirst) }
        return .result(dialog: IntentActions.startPatient(app, focus: IntentSupport.focus(topic)))
    }
}
