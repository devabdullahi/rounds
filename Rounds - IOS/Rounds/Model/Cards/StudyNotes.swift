import Foundation

/// Text read from a student's own notes (a PDF or photos), ready to send for cards. Early preview.
struct StudyNotes: Equatable, Sendable {
    /// What was picked, shown on the form: a file name, or "3 photos".
    let title: String
    /// How much was read, in the student's terms: "3 pages", "2 photos".
    let amount: String
    /// Cleaned text, within `maxLength`.
    let text: String
    /// The notes ran past `maxLength` and only the start is used.
    let wasTrimmed: Bool

    /// The server's bounds: below the minimum there's too little to write fair cards from.
    static let minLength = 200
    static let maxLength = 30_000

    /// Nil when the notes don't have enough readable text.
    init?(title: String, amount: String, raw: String) {
        let cleaned = Self.clean(raw)
        guard cleaned.count >= Self.minLength else { return nil }
        self.title = title
        self.amount = amount
        wasTrimmed = cleaned.count > Self.maxLength
        text = wasTrimmed ? String(cleaned.prefix(Self.maxLength)) : cleaned
    }

    /// Layout noise out: spaces inside a line collapse, blank lines go, line breaks stay
    /// (they separate bullet points, which the card writer reads as separate ideas).
    static func clean(_ raw: String) -> String {
        raw.components(separatedBy: .newlines)
            .map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// The line under the picked notes: what was read, or that only the start is used.
    var summary: String {
        wasTrimmed ? "Long notes: only the first part is used" : "\(amount) read"
    }

    /// "1 page", "3 pages": counts with the right plural.
    static func count(_ n: Int, _ singular: String) -> String {
        "\(n) \(singular)\(n == 1 ? "" : "s")"
    }

    /// "Notes · Cardio lecture", kept within the server's 40 characters. Only a fallback: the server
    /// names the deck after the topic it finds in the notes.
    var deckName: String {
        let name = "Notes · " + title
        return name.count <= 40 ? name : String(name.prefix(39)) + "…"
    }
}
