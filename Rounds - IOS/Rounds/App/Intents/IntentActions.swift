import AppIntents

/// What each Rounds action does and says, kept apart from the intent types so the actions stay
/// small and their wording lives in one place.
@MainActor
enum IntentActions {
    /// Needs the app in front: a case is interactive.
    static func startPatient(_ app: AppState, focus: FocusSelection) -> IntentDialog {
        // A case already open is the next patient; don't stack another on top.
        guard app.activeCase == nil else { return "Your current patient is still waiting." }
        app.showTodayRequested = true
        // Admitting can take minutes for a new topic; the Today tab shows the progress, so Siri
        // doesn't wait on it.
        Task { await app.admit(focus: focus) }
        return focus.isMix ? "Admitting your next patient." : "Admitting a patient from \(focus.label)."
    }

    static func queuePatient(_ app: AppState, focus: FocusSelection) async -> IntentDialog {
        switch await app.queuePatient(focus: focus) {
        case .ready(let patient):
            // The notification is the point when an automation runs it: it's what the student sees.
            await app.announce(title: "New patient waiting", body: patient.map { "“\($0.quote)” · \($0.meta)" } ?? "Open Rounds to meet them.")
            return "Your next patient is on the ward."
        case .preparing:
            return "Rounds is still writing the first case for \(focus.isMix ? "that topic" : focus.label). Try again in a few minutes."
        case .failed(let message):
            return "I couldn't queue a patient. \(message)"
        }
    }

    static func makeCards(_ app: AppState, focus: FocusSelection, count: Int) async -> IntentDialog {
        let store = app.flashcards
        // One deck at a time: say so instead of "couldn't make those cards".
        guard !store.isGenerating else { return "A deck is already being made. It'll be in Cards when it's ready." }
        let deck = FlashcardStore.deckName(for: focus)
        let done = await IntentSupport.run(waitingUpTo: IntentSupport.deckWait) {
            await store.generate(focus: focus, count: count, includeMisses: false)
        } later: { ok in
            await app.announce(title: ok ? "Your cards are ready" : "Couldn't make your cards",
                               body: ok ? "\(deck) is waiting in Cards." : store.problem ?? "Try again in the app.")
        }
        switch done {
        case true?: return "Made \(count) \(deck) cards. They're in Cards."
        case false?: return "I couldn't make those cards. \(store.problem ?? "Try again in the app.")"
        case nil: return "Making your \(deck) cards. I'll let you know when they're ready."
        }
    }

    static func reviewMistakes(_ app: AppState, count: Int) async -> IntentDialog {
        let store = app.flashcards
        // One deck at a time: say so instead of "couldn't make those cards".
        guard !store.isGenerating else { return "A deck is already being made. It'll be in Cards when it's ready." }
        let done = await IntentSupport.run(waitingUpTo: IntentSupport.deckWait) {
            await store.generateFromMistakes(count: count)
        } later: { ok in
            await app.announce(title: ok ? "Your mistakes deck is ready" : "Couldn't make your mistakes deck",
                               body: ok ? "\(FlashcardStore.mistakesDeck) is waiting in Cards." : store.problem ?? "Try again in the app.")
        }
        switch done {
        case true?: return "Your \(FlashcardStore.mistakesDeck) deck is ready in Cards."
        case false?: return "I couldn't make that deck. \(store.problem ?? "Try again in the app.")"
        case nil: return "Making cards from your mistakes. I'll let you know when they're ready."
        }
    }

    /// The day count (0 without a streak) and what to say about it.
    static func streak(_ app: AppState) async -> (days: Int, dialog: IntentDialog) {
        await app.refresh()
        guard app.streak > 0, let left = app.streakTimeLeft else {
            return (0, "No streak right now. Finish a case to start one.")
        }
        return (app.streak, "\(Streak.daysText(app.streak)). \(Streak.timeLeftText(left)).")
    }
}
