import Foundation

/// What a generate request returns: the new cards, and how many decks are left today when the
/// server says (older servers don't).
struct GeneratedDeck: Sendable {
    let cards: [Flashcard]
    let allowance: DeckAllowance?
}
