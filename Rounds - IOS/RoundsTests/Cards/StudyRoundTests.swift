import Testing
@testable import Rounds

/// Leaving the Flashcards tab and coming back keeps the round; only a new deck or Restart resets it.
@MainActor
struct StudyRoundTests {
    @Test func comingBackKeepsTheRound() {
        let store = FlashcardStore(service: nil)
        store.startRoundIfNeeded()   // first visit
        store.known = 3
        store.missed = 1
        store.startRoundIfNeeded()   // back from another tab
        #expect(store.known == 3)
        #expect(store.missed == 1)
    }

    @Test func restartingStartsFresh() {
        let store = FlashcardStore(service: nil)
        store.startRoundIfNeeded()
        store.known = 3
        store.startRound()
        #expect(store.known == 0)
        #expect(store.missed == 0)
    }
}
