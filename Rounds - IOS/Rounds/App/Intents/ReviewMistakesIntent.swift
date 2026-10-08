import AppIntents

/// "Review my mistakes in Rounds": a deck from the student's wrong diagnoses and missed red flags.
struct ReviewMistakesIntent: AppIntent {
    static let title: LocalizedStringResource = "Review My Mistakes"
    static let description = IntentDescription("Makes flashcards from your wrong diagnoses and missed red flags.")

    @Parameter(title: "Cards", default: .twenty)
    var count: CardCountOption

    @Dependency private var app: AppState

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard IntentSupport.isSignedIn else { return .result(dialog: IntentSupport.signInFirst) }
        let store = app.flashcards
        let count = count.rawValue
        let done = await IntentSupport.run(waitingUpTo: IntentSupport.deckWait) {
            await store.generateFromMistakes(count: count)
        } later: { ok in
            await app.announce(title: ok ? "Your mistakes deck is ready" : "Couldn't make your mistakes deck",
                               body: ok ? "\(FlashcardStore.mistakesDeck) is waiting in Cards." : store.problem ?? "Try again in the app.")
        }
        switch done {
        case true?: return .result(dialog: "Your \(FlashcardStore.mistakesDeck) deck is ready in Cards.")
        case false?: return .result(dialog: "I couldn't make that deck. \(store.problem ?? "Try again in the app.")")
        case nil: return .result(dialog: "Making cards from your mistakes. I'll let you know when they're ready.")
        }
    }
}
