import Foundation

/// What badges are judged on: the student's whole record.
struct BadgeRecord: Sendable {
    var rating: Int
    var bestStreak: Int
    var cases: [GradedCase]
    /// Flashcard decks the student generated, and those made from their notes or their misses.
    var decksGenerated = 0
    var notesDecks = 0
    var missDecks = 0
    /// Flashcards marked "Knew it", all time.
    var cardsKnown = 0
}
