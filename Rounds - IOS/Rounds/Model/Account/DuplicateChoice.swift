import Foundation

/// The student's answer when a sign-in looks like a second account (see `KnownAccount`).
enum DuplicateChoice: Sendable {
    /// Move this sign-in method onto the account they used before.
    case useEarlier
    /// Keep the new account; it's a different person or they want it separate.
    case keepNew
}
