import AppIntents

/// "Ask Rounds": Siri asks what to do, and the student answers in their own words ("queue me a hard
/// heme patient", "quiz me on 10 cardiology cards"). Apple's on-device model reads it where
/// available, keywords elsewhere, and the matching action runs. Siri phrases can't carry free
/// text, so this is the two-turn way to say anything.
struct AskRoundsIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Ask Rounds"
    static let description = IntentDescription(
        "Tell Rounds what you want in your own words: a patient now or later, flashcards on a topic, a deck from your mistakes, or your streak.")

    @Parameter(title: "Request", requestValueDialog: "What should Rounds do?")
    var request: String

    @Dependency private var app: AppState

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard IntentSupport.isSignedIn else { return .result(dialog: IntentSupport.signInFirst) }
        let command = await LiveCommandInterpreter().interpret(request)
        let focus = { (topic: StudyFocus?) in topic.map { FocusSelection([$0]) } ?? IntentSupport.savedFocus }
        switch command {
        case .startPatient(let topic):
            try await requestToContinueInForeground("Open Rounds to meet your patient?")
            return .result(dialog: IntentActions.startPatient(app, focus: focus(topic)))
        case .queuePatient(let topic):
            return .result(dialog: await IntentActions.queuePatient(app, focus: focus(topic)))
        case .makeCards(let topic, let count):
            return .result(dialog: await IntentActions.makeCards(app, focus: focus(topic), count: count ?? 20))
        case .reviewMistakes(let count):
            return .result(dialog: await IntentActions.reviewMistakes(app, count: count ?? 20))
        case .streak:
            return .result(dialog: await IntentActions.streak(app).dialog)
        case .unclear:
            return .result(dialog: "I can start or queue a patient, make flashcards, review your mistakes, or check your streak. Try \"queue a cardiology patient\".")
        }
    }
}
