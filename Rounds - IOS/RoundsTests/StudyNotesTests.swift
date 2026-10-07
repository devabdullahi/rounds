import Foundation
import Testing
@testable import Rounds

/// Text read from a student's notes, before it's sent for cards.
struct StudyNotesTests {
    @Test func layoutNoiseIsRemoved() {
        #expect(StudyNotes.clean("  Heart   failure \n\n\n  - BNP  up  \n") == "Heart failure\n- BNP up")
    }

    @Test func tooLittleTextIsRejected() {
        #expect(StudyNotes(title: "scan", amount: "1 page", raw: "Page 1\n\n  ") == nil)
        #expect(StudyNotes(title: "scan", amount: "1 page", raw: String(repeating: "x", count: StudyNotes.minLength - 1)) == nil)
    }

    @Test func longNotesAreTrimmed() throws {
        let notes = try #require(StudyNotes(title: "Book", amount: "40 pages", raw: String(repeating: "a", count: StudyNotes.maxLength + 500)))
        #expect(notes.wasTrimmed)
        #expect(notes.text.count == StudyNotes.maxLength)
        #expect(notes.summary == "Long notes: only the first part is used")
    }

    @Test(arguments: [(1, "1 page"), (3, "3 pages")])
    func amountsReadNaturally(n: Int, label: String) throws {
        #expect(StudyNotes.count(n, "page") == label)
        let notes = try #require(StudyNotes(title: "Lecture", amount: label, raw: String(repeating: "Study line here.\n", count: 20)))
        #expect(notes.summary == "\(label) read")
    }

    @Test(arguments: [("Cardio", "Notes · Cardio"),
                      (String(repeating: "L", count: 60), "Notes · " + String(repeating: "L", count: 31) + "…")])
    func deckNamesFitTheServer(title: String, deck: String) throws {
        let notes = try #require(StudyNotes(title: title, amount: "2 pages", raw: String(repeating: "Study line here.\n", count: 20)))
        #expect(notes.deckName == deck)
        #expect(notes.deckName.count <= 40)
    }
}
