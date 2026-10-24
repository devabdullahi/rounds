import AppIntents

/// "Review my mistakes in Rounds": a deck from the student's wrong diagnoses and missed red flags.
struct ReviewMistakesIntent: AppIntent {
    static let title: LocalizedStringResource = "Review My Mistakes"
    static let description = IntentDescription("Makes flashcards from your wrong diagnoses and missed red flags.")
    /// It spends the account's AI allowance, so it waits for Face ID or the passcode on a locked phone.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Cards", default: .twenty)
    var count: CardCountOption

    @Dependency private var app: AppState

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard IntentSupport.isReady else { return .result(dialog: IntentSupport.openAppFirst) }
        return .result(dialog: await IntentActions.reviewMistakes(app, count: count.rawValue))
    }
}
