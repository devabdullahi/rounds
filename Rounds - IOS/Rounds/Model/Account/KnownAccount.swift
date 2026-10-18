import Foundation

/// The last account that signed in on this device, remembered so a second sign-in method doesn't
/// quietly become a second account. Apple's Hide My Email gives a relay address that can't be
/// matched to the student's Google account, so the server alone can't tell they're one person.
/// Only what the prompt shows is kept: the id, the provider and a masked email.
struct KnownAccount: Codable, Equatable, Sendable {
    let id: String
    /// "apple", "google" or "email".
    let provider: String
    /// "j•••@gmail.com", or nil for a relay or missing address.
    let maskedEmail: String?

    static let storageKey = "lastAccount"
    /// A sign-in this recent made the account just now, rather than finding an old one.
    static let newAccountWindow: TimeInterval = 15 * 60

    init(id: String, provider: String, maskedEmail: String?) {
        self.id = id
        self.provider = provider
        self.maskedEmail = maskedEmail
    }

    init(_ account: Account) {
        self.init(id: account.id, provider: account.provider, maskedEmail: account.email.flatMap(Self.mask))
    }

    var providerLabel: String {
        switch provider {
        case "apple": "Apple"
        case "google": "Google"
        default: "email"
        }
    }

    /// The provider to sign in with to reach this account; nil for email, which has no sheet.
    var socialProvider: SocialProvider? {
        switch provider {
        case "apple": .apple
        case "google": .google
        default: nil
        }
    }

    /// "jane.doe@gmail.com" → "j•••@gmail.com". Apple relay addresses mean nothing to the student, so they're left out.
    static func mask(_ email: String) -> String? {
        let parts = email.split(separator: "@", maxSplits: 1)
        guard parts.count == 2, let first = parts[0].first, !parts[1].hasSuffix("privaterelay.appleid.com") else { return nil }
        return "\(first)•••@\(parts[1])"
    }

    /// The earlier account to offer when `signedIn` looks like a duplicate of it: a different
    /// account, made moments ago, not onboarded yet, signed in with the other social provider than
    /// the one this device used before. Nil means sign in as usual.
    static func duplicate(of previous: KnownAccount?, signedIn: Account, now: Date = .now) -> KnownAccount? {
        guard let previous, previous.id != signedIn.id, previous.socialProvider != nil,
              previous.provider != signedIn.provider, !signedIn.onboarded,
              now.timeIntervalSince(signedIn.createdAt) < newAccountWindow else { return nil }
        return previous
    }
}
