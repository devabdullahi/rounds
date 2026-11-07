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

    @Test func aDeckRefusedForWantOfAPlanOffersPlansNotAnError() async {
        let store = FlashcardStore(service: NoPlanCardService())
        var offered = false
        store.onPlanNeeded = { offered = true }
        let made = await store.generateFromMistakes(count: 10)
        #expect(made == false)
        #expect(offered)
        #expect(store.problem == nil)
    }
}

/// A card service whose server says every deck needs a plan (HTTP 402).
private struct NoPlanCardService: CardService {
    func cards() async throws -> [Flashcard] { [] }
    func add(_ card: Flashcard) async throws -> Flashcard { card }
    func generate(topics: [String], count: Int, includeMisses: Bool, deck: String) async throws -> GeneratedDeck { throw PlanRequiredError() }
    func generate(notes: String, count: Int, deck: String) async throws -> GeneratedDeck { throw PlanRequiredError() }
    func generateFromMistakes(count: Int, deck: String) async throws -> GeneratedDeck { throw PlanRequiredError() }
    func clearMine() async throws {}
}
