import Foundation
import Testing
@testable import Rounds

/// Signing out leaves nothing of that account for the next one on the device.
@MainActor
struct SignOutResetTests {
    @Test func resetClearsDeviceWideKeys() {
        let defaults = UserDefaults.standard
        defaults.set(["platinum"], forKey: AppState.seenBadgesStorageKey)
        defaults.set(42, forKey: FlashcardStore.knownTotalKey)
        defaults.set(["X1"], forKey: AppState.skippedStorageKey)
        let app = AppState(cases: nil, cards: nil)

        app.reset()

        #expect(defaults.object(forKey: AppState.seenBadgesStorageKey) == nil)
        #expect(defaults.object(forKey: FlashcardStore.knownTotalKey) == nil)
        #expect(defaults.object(forKey: AppState.skippedStorageKey) == nil)
        #expect(app.flashcards.knownTotal == 0)
        #expect(app.activeCase == nil)
        #expect(app.pendingUnlocks.isEmpty)
    }
}
