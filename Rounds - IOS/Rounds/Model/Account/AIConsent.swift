import Foundation

/// The student's one-time agreement that what they type and say in a case goes to Rounds' AI
/// providers (through our server) to play the patient, write cases and grade. Required before any
/// of that happens (App Review 5.1.2(i)). Stored on this device as the version of the wording that
/// was agreed to: changing what is shared means bumping `currentVersion`, which asks again.
enum AIConsent {
    /// `@AppStorage(AIConsent.storageKey)`: the agreed version, 0 when never agreed.
    static let storageKey = "aiConsentVersion"
    /// The wording in `AIConsent.points`. Bump when what's shared or who it's shared with changes.
    static let currentVersion = 1
    /// Who receives the student's questions, answers and voice, named on the consent screen.
    static let providers = "OpenAI and DeepSeek"

    /// Whether a stored version covers the current wording.
    static func isGiven(stored: Int) -> Bool { stored >= currentVersion }

    /// What to store when the student taps "I agree".
    static var agreed: Int { currentVersion }

    /// The stored value after signing out, so the next student on this phone is asked again.
    static let withdrawn = 0

    /// The plain bullets shown before agreeing, in order.
    static let points: [String] = [
        "The patients are fictional, played by AI.",
        "Your typed questions, answers and voice are sent through our server to our AI providers (\(providers)) to write replies, cases and grades.",
        "Never enter real patient information.",
        "For practice only, not medical advice.",
    ]
}
