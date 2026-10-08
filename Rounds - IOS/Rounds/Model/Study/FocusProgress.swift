import Foundation

/// How much of the student's focus they've worked through: different patients graded in it, out of
/// the conditions it can draw from.
struct FocusProgress: Equatable, Sendable {
    let done: Int
    let total: Int

    var share: Double { total == 0 ? 0 : Double(done) / Double(total) }

    /// Nil until the condition counts load. `counts` is keyed by `StudyFocus.stored`; a mix counts
    /// every topic, and several picks add up (a condition in two picks counts twice, so it's an estimate).
    static func of(_ graded: [GradedCase], in selection: FocusSelection, counts: [String: Int]) -> FocusProgress? {
        guard !counts.isEmpty else { return nil }
        let total = selection.isMix ? counts.values.reduce(0, +) : selection.items.reduce(0) { $0 + (counts[$1.stored] ?? 0) }
        let patients = graded.filter { c in
            if selection.isMix { return true }
            guard let rotation = c.clerkship, let system = c.system else { return false }
            return selection.matches(rotation: rotation, system: system)
        }
        // Retrying a patient doesn't cover a new condition.
        let done = Set(patients.map { $0.caseID ?? $0.id }).count
        return FocusProgress(done: min(done, total), total: total)
    }
}
