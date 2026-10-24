import Foundation

/// The case screen's three working views, in the order a student usually goes: talk to the patient,
/// examine them, order tests. Diagnosing is the step after these, a screen of its own.
enum WorkupStep: Hashable, CaseIterable, Sendable {
    case ask, examine, tests

    /// Questions asked before the step bar points at the exam: enough history that examining makes sense.
    static let questionsBeforeExam = 4
    /// Exam steps done before it points at tests.
    static let examBeforeTests = 2

    /// The step worth trying next, marked on the step bar, or nil when nothing is being skipped.
    /// Students tended to stay in the chat and never find the exam or the tests; this nudges them
    /// there once the history is underway, and goes quiet as soon as they've started each one.
    static func hint(questionsAsked: Int, examDone: Int, testsDone: Int) -> WorkupStep? {
        if examDone == 0 { return questionsAsked >= questionsBeforeExam ? .examine : nil }
        if testsDone == 0 { return examDone >= examBeforeTests ? .tests : nil }
        return nil
    }

    /// The coach card's words when the step bar points here: a short verdict on the step just done,
    /// and one concrete thing to try. The exam's suggestion is the first maneuver on the exam list,
    /// what the student would see first on opening Examine anyway, so it gives nothing away.
    static func nudge(for step: WorkupStep, firstManeuver: String?, sex: String) -> (title: String, detail: String)? {
        switch step {
        case .ask:
            return nil
        case .examine:
            let pronoun = sex.uppercased().hasPrefix("M") ? "him" : sex.uppercased().hasPrefix("F") ? "her" : "them"
            guard let first = firstManeuver?.trimmingCharacters(in: .whitespaces), !first.isEmpty else {
                return ("Good history. Time to examine.", "Look, listen and feel. Findings go on \(pronoun == "them" ? "their" : pronoun == "him" ? "his" : "her") chart.")
            }
            return ("Good history. Time to examine \(pronoun).", "Start with: \(first.prefix(1).lowercased() + first.dropFirst()).")
        case .tests:
            return ("Good exam. Time for tests.", "Order the ones that would change what you do next.")
        }
    }
}
