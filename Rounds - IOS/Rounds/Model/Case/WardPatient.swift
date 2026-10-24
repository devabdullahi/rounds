import Foundation

/// A patient on the student's ward: one generated case and how it went so far.
struct WardPatient: Identifiable, Hashable {
    let id: String              // bed, e.g. "C42"
    let quote: String
    let meta: String            // "F · 78 · Family medicine"
    let rotation: Clerkship?
    let system: OrganSystem?
    let hr: Int?
    let bp: String?
    let spo2: Int?
    var status: Status
    /// Red flags missed on the latest graded attempt, and its score.
    var misses: [Miss] = []
    /// The case's real diagnosis when the latest graded attempt got it wrong; nil when it was right.
    var missedDiagnosis: String?
    var lastScore: Int?
    /// Graded attempts at this patient, for "Previous tries".
    var tries = 0
    /// The door-note summary ("65-year-old man with 6 months of trouble walking"); empty on older rows.
    var complaint = ""
    /// Key history areas in the case, and how many a half-done attempt has found (nil until known).
    var historyTotal = 0
    var historyFound: Int?

    /// The complaint without the age and sex the meta line already gives, capitalized, for a
    /// one-glance title: "6 months of trouble walking". Falls back to the patient's quote.
    var shortComplaint: String {
        var text = complaint.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: #"^[^,]*?\b\d+[- ](?:year|month|week|day)s?[- ]old\s+\w+(?:\s+(?:with|presenting with|reporting|complaining of))?[\s,]+"#,
                                  options: [.regularExpression, .caseInsensitive]) {
            text.removeSubrange(range)
        }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: " .,"))
        guard !text.isEmpty else { return "\u{201C}\(quote)\u{201D}" }
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    enum Status: Hashable { case new, resume, revisit, done }

    func fits(_ focus: FocusSelection) -> Bool {
        focus.isMix || focus.items.contains { item in
            switch item {
            case .mix: true
            case .rotation(let c): c == rotation
            case .system(let s): s == system
            }
        }
    }
}
