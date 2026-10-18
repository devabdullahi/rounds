import Foundation
import Testing
@testable import Rounds

/// When a sign-in counts as a second account of someone this device already knows.
@Suite("Known account")
struct KnownAccountTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let google = KnownAccount(id: "old", provider: "google", maskedEmail: "j•••@gmail.com")

    private func account(id: String = "new", provider: String = "apple", onboarded: Bool = false, age: TimeInterval = 30) -> Account {
        Account(id: id, email: "x7k2@privaterelay.appleid.com", name: nil, provider: provider,
                createdAt: now.addingTimeInterval(-age), onboarded: onboarded)
    }

    @Test func aBrandNewAccountFromTheOtherProviderIsOfferedTheEarlierOne() {
        #expect(KnownAccount.duplicate(of: google, signedIn: account(), now: now) == google)
    }

    @Test(arguments: [
        ("same account", "old", "apple", false, 30.0),
        ("same provider", "new", "google", false, 30.0),
        ("already onboarded", "new", "apple", true, 30.0),
        ("an old account", "new", "apple", false, 3600.0),
    ])
    func otherSignInsGoStraightIn(_ why: String, id: String, provider: String, onboarded: Bool, age: TimeInterval) {
        #expect(KnownAccount.duplicate(of: google, signedIn: account(id: id, provider: provider, onboarded: onboarded, age: age), now: now) == nil, "\(why)")
    }

    @Test func nothingIsOfferedWithoutAnEarlierSocialAccount() {
        #expect(KnownAccount.duplicate(of: nil, signedIn: account(), now: now) == nil)
        let email = KnownAccount(id: "old", provider: "email", maskedEmail: "s•••@school.edu")
        #expect(KnownAccount.duplicate(of: email, signedIn: account(), now: now) == nil)   // no sheet to sign in with
    }

    @Test(arguments: [("jane.doe@gmail.com", "j•••@gmail.com"), ("x7k2@privaterelay.appleid.com", nil), ("nonsense", nil)])
    func emailsAreMaskedAndRelayAddressesHidden(email: String, masked: String?) {
        #expect(KnownAccount.mask(email) == masked)
    }
}
