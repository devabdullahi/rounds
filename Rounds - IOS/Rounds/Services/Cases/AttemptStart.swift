import Foundation

/// A started attempt, and the tests its menu leaves out.
struct AttemptStart: Sendable, Equatable {
    let id: String
    /// Tests the condition doesn't call for, hidden in practice mode so the menu teaches the workup.
    /// Empty in exam mode, where they stay on the menu and ordering one costs points. The server
    /// decides (the list comes from the private rubric) and refuses orders for these.
    let hiddenTests: Set<String>
}
