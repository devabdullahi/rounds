import AppIntents

/// "Queue my next patient in Rounds": admits a patient onto the ward without opening the app, so a
/// Shortcuts automation ("every day at 6 PM") can have one waiting. A notification says who's there.
struct QueuePatientIntent: AppIntent {
    static let title: LocalizedStringResource = "Queue Patient"
    static let description = IntentDescription(
        "Admits a new fictional patient to your ward in the background, ready when you open Rounds. Use it in an automation to have a patient waiting at the same time every day.")

    @Parameter(title: "Topic", description: "A specialty or organ system. Leave empty for your saved focus.")
    var topic: IntentTopic?

    static var parameterSummary: some ParameterSummary {
        Summary("Queue a patient from \(\.$topic)")
    }

    @Dependency private var app: AppState

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard IntentSupport.isSignedIn else { return .result(dialog: IntentSupport.signInFirst) }
        return .result(dialog: await IntentActions.queuePatient(app, focus: IntentSupport.focus(topic)))
    }
}
