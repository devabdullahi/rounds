import Foundation
import Supabase

/// Flashcard storage and generation. Models depend on the protocol; `LiveCardService` is Supabase.
protocol CardService: Sendable {
    /// Built-in decks plus the student's own cards, oldest first.
    func cards() async throws -> [Flashcard]
    /// Saves a hand-written card and returns it with its row id.
    func add(_ card: Flashcard) async throws -> Flashcard
    /// Writes a deck from condition profiles for the topics (`StudyFocus.stored` values).
    func generate(topics: [String], count: Int, includeMisses: Bool, deck: String) async throws -> GeneratedDeck
    /// Writes a deck from text read out of the student's own notes (early preview).
    func generate(notes: String, count: Int, deck: String) async throws -> GeneratedDeck
    /// Deletes every card the student wrote or generated. Built-in decks stay.
    func clearMine() async throws
}

// MARK: - Wire types
