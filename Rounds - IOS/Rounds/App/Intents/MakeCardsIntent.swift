import AppIntents

/// "Make flashcards in Rounds": generates a deck for the student's focus (or a named topic)
/// without opening the app.
struct MakeCardsIntent: AppIntent {
    static let title: LocalizedStringResource = "Make Flashcards"
    static let description = IntentDescription("Writes a new flashcard deck on a topic.")
    /// It spends the account's AI allowance, so it waits for Face ID or the passcode on a locked phone.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Topic", description: "A specialty or organ system. Leave empty for your saved focus.")
    var topic: IntentTopic?

    @Parameter(title: "Cards", default: .twenty)
    var count: CardCountOption

    static var parameterSummary: some ParameterSummary {
        Summary("Make \(\.$count) cards on \(\.$topic)")
    }

    @Dependency private var app: AppState

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard IntentSupport.isReady else { return .result(dialog: IntentSupport.openAppFirst) }
        return .result(dialog: await IntentActions.makeCards(app, focus: IntentSupport.focus(topic), count: count.rawValue))
    }
}
