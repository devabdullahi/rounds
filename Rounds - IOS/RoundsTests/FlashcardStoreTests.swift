import Testing
@testable import Rounds

@MainActor
struct FlashcardStoreTests {
    @Test("Deck names come from the chosen topics and stay within 40 characters", arguments: [
        ("", "Mixed topics"),
        ("rotation:surgery", "Surgery"),
        ("rotation:internalMedicine,system:cardiovascular", "Internal medicine + Cardiovascular"),
    ])
    func deckName(stored: String, expected: String) {
        #expect(FlashcardStore.deckName(for: FocusSelection(stored: stored)) == expected)
    }

    @Test func longDeckNamesAreShortened() {
        let many = FocusSelection(stored: "rotation:internalMedicine,rotation:emergency,system:gastrointestinal,system:respiratory")
        #expect(FlashcardStore.deckName(for: many).count <= 40)
    }
}
