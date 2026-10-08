import Foundation

/// What a generate request returns: the new cards, and how many decks are left today when the
/// server says (older servers don't).
struct GeneratedDeck: Sendable {
    /// The deck the cards were saved to. The server may rename it: notes decks take their topic.
    let deck: String
    let cards: [Flashcard]
    let allowance: DeckAllowance?
}
