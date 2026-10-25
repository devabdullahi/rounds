import Foundation

/// The student's one-time agreement before using Rounds: that what they type and say in a case goes
/// to Rounds' AI providers (through our server) to play the patient, write cases and grade (App
/// Review 5.1.2(i)), along with the Terms of Use and Privacy Policy. Given by creating an account,
/// under the sign-in buttons (`SignUpTermsNote`); there is no separate screen. Stored on this device
/// as the version of the wording that was agreed to: changing what is shared, or the terms, means
/// bumping `currentVersion`, which asks again.
enum AIConsent {
    /// `@AppStorage(AIConsent.storageKey)`: the agreed version, 0 when never agreed.
    static let storageKey = "aiConsentVersion"
    /// The wording agreed to (`SignUpTermsNote`). Bump when what's shared, who it's shared with, or
    /// the terms change. 2: added the Terms of Use (2026-10-23).
    static let currentVersion = 2
    /// Who receives the student's questions, answers and voice, named on the consent screen.
    static let providers = "OpenAI and DeepSeek"

    /// Whether a stored version covers the current wording.
    static func isGiven(stored: Int) -> Bool { stored >= currentVersion }

    /// What to store once the student has signed in (making the account is the agreement).
    static var agreed: Int { currentVersion }

    /// The stored value after signing out, so the next student on this phone is asked again.
    static let withdrawn = 0

    /// The agreement under the sign-in buttons, as Markdown with the documents linked (plain titles
    /// when a link isn't set yet).
    static func signUpNote(terms: URL?, privacy: URL?) -> String {
        func link(_ title: String, _ url: URL?) -> String { url.map { "[\(title)](\($0.absoluteString))" } ?? title }
        return "By creating an account, you agree to our \(link("Terms of Use", terms)) and \(link("Privacy Policy", privacy)), "
            + "and that what you type and say goes to our AI providers (\(providers)) to play patients and grade. "
            + "Never enter real patient information."
    }
}
