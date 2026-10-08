import SwiftUI

/// How many conditions a focus can draw new patients from, as a short label: "12 conditions",
/// "Coming soon". nil while the counts haven't loaded (e.g. signed out), so nothing shows.
func conditionCount(_ focus: StudyFocus, in counts: [String: Int]) -> (text: String, empty: Bool)? {
    guard !counts.isEmpty else { return nil }
    let n = counts[focus.stored] ?? 0
    return n == 0 ? ("Coming soon", true) : ("\(n) \(n == 1 ? "condition" : "conditions")", false)
}
