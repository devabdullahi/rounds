import Foundation

/// An attempt the student left before submitting, as the server kept it, so reopening the case
/// continues where they stopped: the conversation, what it uncovered, the exam steps with their
/// findings, the tests with their results, and the clock.
struct ResumedAttempt: Sendable, Equatable {
    struct Turn: Sendable, Equatable {
        let fromStudent: Bool
        let text: String
    }

    struct OrderedTest: Sendable, Equatable {
        let id: String
        let at: Date
        let result: TestResult
    }

    let id: String
    let examMode: Bool
    let timeLimitMinutes: Int?
    let startedAt: Date
    let transcript: [Turn]
    let revealedIDs: Set<String>
    /// The revealed facts' labels in the order they turned up, for "Found so far".
    var revealedLabels: [String] = []
    let coverage: (got: Int, total: Int)
    /// Exam steps in the order done, with their findings.
    let examined: [(id: String, finding: String)]
    let ordered: [OrderedTest]
    let hiddenTests: Set<String>

    static func == (a: ResumedAttempt, b: ResumedAttempt) -> Bool {
        a.id == b.id && a.transcript == b.transcript && a.revealedIDs == b.revealedIDs && a.revealedLabels == b.revealedLabels && a.ordered == b.ordered
            && a.examined.map(\.id) == b.examined.map(\.id) && a.coverage == b.coverage
    }
}
