import Foundation

/// A short teaching summary of the case's condition, shown in the debrief once the answer is out.
/// Comes from the case's condition profile on the server, so it never reaches the app before grading.
struct ConditionAbout: Hashable, Sendable {
    /// The few facts worth remembering, most important first.
    let summaryPoints: [String]
    let symptoms: [String]
    let riskFactors: [String]

    /// True when there is nothing to show, so the debrief can skip the card entirely.
    var isEmpty: Bool { summaryPoints.isEmpty && symptoms.isEmpty && riskFactors.isEmpty }
}
