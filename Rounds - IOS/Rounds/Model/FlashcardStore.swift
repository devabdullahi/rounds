import Foundation
import Observation

/// The student's flashcards: built-in decks plus their own, and the deck they're studying.
@MainActor
@Observable
final class FlashcardStore {
    private let service: (any CardService)?

    private(set) var cards: [Flashcard] = []
    private(set) var isLoading = false
    private(set) var isGenerating = false
    /// Deck being studied; nil studies every card.
    var selectedDeck: String?
    var problem: String?
    /// Shown briefly after a deck is generated ("20 cards added to …").
    var notice: String?

    /// How many cards the generate screen offers.
    static let generateCounts = [10, 20, 30, 50]

    init(service: (any CardService)?) {
        self.service = service
    }

    /// Deck names in the order they first appear, newest generated decks first.
    var decks: [String] {
        var seen: [String] = []
        for card in cards.reversed() where !seen.contains(card.deck) { seen.append(card.deck) }
        return seen
    }

    var mineCount: Int { cards.filter(\.isMine).count }

    /// Cards in the selected deck (all cards when none is selected).
    var studying: [Flashcard] {
        guard let selectedDeck else { return cards }
        return cards.filter { $0.deck == selectedDeck }
    }

    func load() async {
        guard let service, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            cards = try await service.cards()
            if let deck = selectedDeck, !decks.contains(deck) { selectedDeck = nil }
        } catch {
            problem = error.localizedDescription
        }
    }

    func add(_ card: Flashcard) async -> Flashcard? {
        guard let service else { return nil }
        do {
            let saved = try await service.add(card)
            cards.append(saved)
            return saved
        } catch {
            problem = error.localizedDescription
            return nil
        }
    }

    /// Generates a deck for the topics and switches to it. Returns false if it failed.
    func generate(focus: FocusSelection, count: Int, includeMisses: Bool) async -> Bool {
        guard let service, !isGenerating else { return false }
        isGenerating = true
        defer { isGenerating = false }
        let deck = Self.deckName(for: focus)
        do {
            let new = try await service.generate(topics: focus.items.map(\.stored), count: count,
                                                 includeMisses: includeMisses, deck: deck)
            cards.append(contentsOf: new)
            selectedDeck = deck
            notice = "\(new.count) cards added to \(deck)"
            return true
        } catch {
            problem = error.localizedDescription
            return false
        }
    }

    /// Deletes the student's own cards; built-in decks stay.
    func clearMine() async {
        guard let service else { return }
        do {
            try await service.clearMine()
            cards.removeAll(where: \.isMine)
            if let deck = selectedDeck, !decks.contains(deck) { selectedDeck = nil }
        } catch {
            problem = error.localizedDescription
        }
    }

    /// "Internal medicine + Cardiovascular", or "Mixed topics", kept within the server's 40 characters.
    /// Spells out every topic, unlike the focus chip's short "Internal medicine +1".
    static func deckName(for focus: FocusSelection) -> String {
        let name = focus.isMix ? "Mixed topics" : focus.items.map(\.label).joined(separator: " + ")
        return name.count <= 40 ? name : String(name.prefix(39)) + "…"
    }
}
