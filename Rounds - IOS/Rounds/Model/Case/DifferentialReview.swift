import Foundation

/// One condition that could have explained this patient, reviewed against the student's own differential.
struct DifferentialReview: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    /// Dangerous enough that it must be ruled out even when unlikely (shown in red).
    let mustNotMiss: Bool
    /// Why it was a reasonable consideration for this presentation.
    let why: String
    /// Findings that separate it from the actual diagnosis.
    let tellApart: [String]
    /// Whether the student listed it in their submitted differential.
    let inYours: Bool
}

extension DifferentialReview {
    /// The rows a collapsed list shows: the first `limit`, plus any later must-not-miss item,
    /// because a dangerous alternative should never hide behind "Show all". Keeps the server's order.
    static func collapsed(_ items: [DifferentialReview], limit: Int) -> [DifferentialReview] {
        items.enumerated().filter { $0.offset < limit || $0.element.mustNotMiss }.map(\.element)
    }

    /// The muted note under the differential for things the student listed that don't usually
    /// belong here. Nil when there's nothing to say.
    static func extrasNote(_ extras: [String]) -> String? {
        let names = extras.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !names.isEmpty else { return nil }
        let tail = names.count == 1 ? "Not a usual consideration for this case." : "Not usual considerations for this case."
        return "Also on your list: \(names.joined(separator: ", ")). \(tail)"
    }
}
