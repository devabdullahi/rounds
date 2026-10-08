import Foundation

/// The six parts every graded case is scored on. They add up to 100; the raw values match the
/// server's grade breakdown keys.
enum ScoreCategory: String, CaseIterable, Identifiable, Sendable {
    case diagnosis, history, exam, redFlags = "red_flags", tests, plan
    var id: String { rawValue }

    var label: String {
        switch self {
        case .diagnosis: "Diagnosis"
        case .history: "History taking"
        case .exam: "Examination"
        case .redFlags: "Red-flag questions"
        case .tests: "Test selection"
        case .plan: "Plan"
        }
    }

    /// What earns these points, so a weak spot says what to practice.
    var detail: String {
        switch self {
        case .diagnosis: "Naming the condition the patient actually has."
        case .history: "Asking the questions a strong student asks, weighted by how much they matter."
        case .exam: "Doing the exam maneuvers that confirm or rule out the diagnosis."
        case .redFlags: "Screening for the dangerous look-alikes you can't afford to miss."
        case .tests: "Ordering the right tests first, skipping ones that don't change management, staying on budget."
        case .plan: "An immediate plan that fits the diagnosis and its severity."
        }
    }
}
