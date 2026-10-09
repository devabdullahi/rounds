import Foundation
import Observation

/// The student's flashcards: built-in decks plus their own, and the deck they're studying.
@MainActor
@Observable
final class FlashcardStore {
    private let service: (any CardService)?

    private(set) var cards: [Flashcard] = [] { didSet { onProgress?() } }
    /// Called when study progress changes (a card known, a deck added), so badges it earns unlock
    /// in the moment instead of at the next refresh.
    @ObservationIgnored var onProgress: (() -> Void)?
    private(set) var isLoading = false
    /// The first load has finished (successfully or not), so "no cards" is known, not assumed.
    private(set) var hasLoaded = false
    private(set) var isGenerating = false
    /// Text is being read out of picked notes (on the device).
    private(set) var isReadingNotes = false
    /// The study round in progress: cards still to go (a missed card comes back at the end) and the
    /// score so far. Kept on the store, not the screen, so leaving the Flashcards tab and coming
    /// back finds the student where they were.
    var queue: [Flashcard] = []
    var known = 0
    var missed = 0
    /// A round has been dealt this app session; returning to the tab resumes it instead.
    private(set) var roundStarted = false

    /// Starts the selected deck from its first card, with a fresh score.
    func startRound() {
        queue = studying.map { $0.copy() }
        known = 0
        missed = 0
        roundStarted = true
    }

    /// The first visit deals a round; later visits keep the one in progress.
    func startRoundIfNeeded() {
        if !roundStarted { startRound() }
    }

    /// Deck being studied; nil studies every card.
    var selectedDeck: String?
    var problem: String?
    /// Shown briefly after a deck is generated ("20 cards added to …").
    var notice: String?

    /// Decks left today, once a generation has reported it.
    private(set) var allowance: DeckAllowance?
    /// The allowance if it still describes today.
    var allowanceToday: DeckAllowance? { allowance.flatMap { $0.isCurrent() ? $0 : nil } }

    /// Cards marked "Knew it", all time, on this device (the Card shark badge).
    static let knownTotalKey = "flashcardsKnownTotal"
    private(set) var knownTotal = UserDefaults.standard.integer(forKey: FlashcardStore.knownTotalKey)

    /// Counts one more card the student knew.
    func recordKnown() {
        knownTotal += 1
        UserDefaults.standard.set(knownTotal, forKey: Self.knownTotalKey)
        onProgress?()
    }

    /// Decks the student generated (cards with a source), for the study badges.
    var generatedDecks: Int { Set(cards.filter { $0.isMine && $0.source != nil }.map(\.deck)).count }
    /// Decks made from the student's notes.
    var notesDecks: Int { Set(cards.filter { $0.isMine && $0.source == "notes" }.map(\.deck)).count }
    /// Decks built from the student's mistakes: a mistakes review, or any deck with missed-red-flag cards.
    var missDecks: Int {
        Set(cards.filter { $0.isMine && ($0.source == "missed" || $0.deck == Self.mistakesDeck) }.map(\.deck)).count
    }

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
            let generated = try await service.generate(topics: focus.items.map(\.stored), count: count,
                                                 includeMisses: includeMisses, deck: deck)
            let new = generated.cards
            if let left = generated.allowance { allowance = left }
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

    /// The deck a mistakes review is saved to.
    static let mistakesDeck = "My mistakes"

    /// Generates a deck from the student's mistakes and switches to it. Returns false if it failed.
    func generateFromMistakes(count: Int) async -> Bool {
        guard let service, !isGenerating else { return false }
        isGenerating = true
        defer { isGenerating = false }
        do {
            let generated = try await service.generateFromMistakes(count: count, deck: Self.mistakesDeck)
            if let left = generated.allowance { allowance = left }
            cards.append(contentsOf: generated.cards)
            selectedDeck = generated.deck
            notice = "\(generated.cards.count) cards added to \(generated.deck)"
            return true
        } catch {
            problem = error.localizedDescription
            return false
        }
    }

    /// Generates a deck from the student's notes and switches to it. Returns false if it failed.
    func generate(notes: StudyNotes, count: Int) async -> Bool {
        guard let service, !isGenerating else { return false }
        isGenerating = true
        defer { isGenerating = false }
        do {
            let generated = try await service.generate(notes: notes.text, count: count, deck: notes.deckName)
            let new = generated.cards
            if let left = generated.allowance { allowance = left }
            cards.append(contentsOf: new)
            // The server names notes decks after their topic ("Heart failure"), so use its name.
            selectedDeck = generated.deck
            notice = "\(new.count) cards added to \(generated.deck)"
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
