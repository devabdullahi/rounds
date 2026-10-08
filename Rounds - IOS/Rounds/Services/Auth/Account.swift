import Foundation
import Supabase

/// A signed-in Rounds account (not an anonymous guest session).
struct Account: Equatable, Sendable {
    let id: String
    let email: String?
    let name: String?
    /// "email", "apple" or "google".
    let provider: String
    let createdAt: Date
    /// Profile photo: one the student uploaded, else the one Google shares. Nil shows initials.
    var avatarURL: URL?
    /// The specialty they're aiming for; nil until they pick one.
    var specialty: Specialty?
    /// Finished onboarding (the promise). Kept on the account, not the device, so every way of
    /// signing in (code, Apple, Google, a new phone) routes the same way.
    var onboarded = false

    /// Up to two initials for the avatar; "?" without a name or email.
    var initials: String {
        let source = name ?? email ?? ""
        let words = source.split(whereSeparator: { $0 == " " || $0 == "@" || $0 == "." }).prefix(2)
        let letters = words.compactMap(\.first).map { String($0).uppercased() }.joined()
        return letters.isEmpty ? "?" : letters
    }

    var providerLabel: String {
        switch provider {
        case "apple": "Apple"
        case "google": "Google"
        default: "Email"
        }
    }
}
