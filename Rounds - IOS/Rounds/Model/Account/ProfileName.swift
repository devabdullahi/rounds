import Foundation

/// The rule for a name the student types for themselves: what gets saved, or nil when there's
/// nothing to save. Shown on Profile and used to greet them, so it stays one short line.
enum ProfileName {
    static let maxLength = 50
    /// The name typed during onboarding, kept on the device until the account exists to take it.
    static let storageKey = "onboardingName"

    /// Trimmed, inner runs of spaces and line breaks collapsed, capped at `maxLength`; nil if empty.
    static func clean(_ typed: String) -> String? {
        let words = typed.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return nil }
        return String(words.joined(separator: " ").prefix(maxLength))
            .trimmingCharacters(in: .whitespaces)
    }
}
