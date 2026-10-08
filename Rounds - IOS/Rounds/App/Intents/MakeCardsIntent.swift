import AppIntents

/// "Make flashcards in Rounds": generates a deck for the student's focus (or a named topic)
/// without opening the app.
struct MakeCardsIntent: AppIntent {
    static let title: LocalizedStringResource = "Make Flashcards"
    static let description = IntentDescription("Writes a new flashcard deck on a topic.")

    @Parameter(title: "Topic", description: "A rotation or organ system. Leave empty for your saved focus.")
    var topic: IntentTopic?

    @Parameter(title: "Cards", default: .twenty)
    var count: CardCountOption

    static var parameterSummary: some ParameterSummary {
        Summary("Make \(\.$count) cards on \(\.$topic)")
    }

    @Dependency private var app: AppState

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard IntentSupport.isSignedIn else { return .result(dialog: IntentSupport.signInFirst) }
        let store = app.flashcards
        let focus = IntentSupport.focus(topic)
        let deck = FlashcardStore.deckName(for: focus)
        let count = count.rawValue
        let done = await IntentSupport.run(waitingUpTo: IntentSupport.deckWait) {
            await store.generate(focus: focus, count: count, includeMisses: false)
        } later: { ok in
            await app.announce(title: ok ? "Your cards are ready" : "Couldn't make your cards",
                               body: ok ? "\(deck) is waiting in Cards." : store.problem ?? "Try again in the app.")
        }
        switch done {
        case true?: return .result(dialog: "Made \(count) \(deck) cards. They're in Cards.")
        case false?: return .result(dialog: "I couldn't make those cards. \(store.problem ?? "Try again in the app.")")
        case nil: return .result(dialog: "Making your \(deck) cards. I'll let you know when they're ready.")
        }
    }
}
