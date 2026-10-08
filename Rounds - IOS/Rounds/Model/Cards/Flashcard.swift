import Foundation

/// One flashcard: a question on the front, the answer on the back.
struct Flashcard: Identifiable, Equatable, Sendable {
    /// Local identity: a re-queued copy of a missed card gets a new one so the deck animates it.
    let id: UUID
    /// Row id in the database; nil for a card not saved yet.
    var serverID: String?
    var deck: String
    let topic: String
    let front: String
    let back: String
    var color: CardColor = .standard
    /// Condition profile a generated card came from ("atrial-fibrillation"), or "missed" for the
    /// student's own missed red flags; nil for hand-written cards.
    var source: String?
    /// The student's own card (written or generated), as opposed to a built-in deck.
    var isMine = true

    init(id: UUID = UUID(), serverID: String? = nil, deck: String = Flashcard.myDeck, topic: String, front: String,
         back: String, color: CardColor = .standard, source: String? = nil, isMine: Bool = true) {
        self.id = id
        self.serverID = serverID
        self.deck = deck
        self.topic = topic
        self.front = front
        self.back = back
        self.color = color
        self.source = source
        self.isMine = isMine
    }

    /// Deck that hand-written cards go into.
    static let myDeck = "My cards"

    /// Same content, new identity (for re-queuing a missed card).
    func copy() -> Flashcard {
        Flashcard(serverID: serverID, deck: deck, topic: topic, front: front, back: back, color: color, source: source, isMine: isMine)
    }
}
