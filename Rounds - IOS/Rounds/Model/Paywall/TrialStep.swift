import Foundation

/// One row of the paywall's "what happens next" timeline.
struct TrialStep: Equatable, Sendable {
    enum Kind: Sendable { case access, reminder, billing, renewal }
    let kind: Kind
    let when: String
    let what: String
}
