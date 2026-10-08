import Foundation
import Observation

/// The student's flashcards: built-in decks plus their own, and the deck they're studying.
@MainActor
@Observable
final class FlashcardStore {
    private let service: (any CardService)?

    private(set) var cards: [Flashcard] = []
    private(set) var isLoading = false
    /// The first load has finished (successfully or not), so "no cards" is known, not assumed.
    private(set) var hasLoaded = false
    private(set) var isGenerating = false
    /// Text is being read out of picked notes (on the device).
    private(set) var isReadingNotes = false
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
        defer { isLoading = false; hasLoaded = true }
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

    /// Reads a picked PDF. Nil, with `problem` set, when it has too little readable text.
    func readNotes(pdf url: URL) async -> StudyNotes? {
        let title = url.deletingPathExtension().lastPathComponent
        isReadingNotes = true
        defer { isReadingNotes = false }
        let read = await NotesReader.text(fromPDF: url)
        return notes(title: title, amount: StudyNotes.count(read.pages, "page"), raw: read.text)
    }

    /// Reads picked photos of notes. Nil, with `problem` set, when they have too little readable text.
    func readNotes(photos: [Data]) async -> StudyNotes? {
        let amount = StudyNotes.count(min(photos.count, NotesReader.maxPhotos), "photo")
        isReadingNotes = true
        defer { isReadingNotes = false }
        return notes(title: amount, amount: amount, raw: await NotesReader.text(fromPhotos: photos))
    }

    /// Reads pages from the document scanner. Nil, with `problem` set, when they have too little readable text.
    func readNotes(scans: [Data]) async -> StudyNotes? {
        let amount = StudyNotes.count(min(scans.count, NotesReader.maxPages), "page")
        isReadingNotes = true
        defer { isReadingNotes = false }
        return notes(title: "Scanned notes", amount: amount, raw: await NotesReader.text(fromScans: scans))
    }

    private func notes(title: String, amount: String, raw: String) -> StudyNotes? {
        guard let notes = StudyNotes(title: title, amount: amount, raw: raw) else {
            problem = "We couldn\u{2019}t read enough text in that. Try a clearer photo, or a PDF with selectable text."
            return nil
        }
        return notes
    }

    /// Generates a deck from the student's notes and switches to it. Returns false if it failed.
    func generate(notes: StudyNotes, count: Int) async -> Bool {
        guard let service, !isGenerating else { return false }
        isGenerating = true
        defer { isGenerating = false }
        do {
            let new = try await service.generate(notes: notes.text, count: count, deck: notes.deckName)
            cards.append(contentsOf: new)
            selectedDeck = notes.deckName
            notice = "\(new.count) cards added to \(notes.deckName)"
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
