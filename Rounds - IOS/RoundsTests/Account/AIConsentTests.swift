import Foundation
import Testing
@testable import Rounds

/// The AI consent's stored-version rules and the sign-up wording that gives it.
struct AIConsentTests {
    @Test(arguments: [(0, false), (AIConsent.currentVersion - 1, false), (AIConsent.currentVersion, true),
                      (AIConsent.currentVersion + 1, true)])
    func storedVersionCoversTheCurrentWording(stored: Int, given: Bool) {
        #expect(AIConsent.isGiven(stored: stored) == given)
    }

    @Test func agreeingStoresAVersionThatCounts() {
        #expect(AIConsent.isGiven(stored: AIConsent.agreed))
    }

    @Test func withdrawingAsksAgain() {
        #expect(!AIConsent.isGiven(stored: AIConsent.withdrawn))
    }

    @Test func neverAgreedReadsAsNotGiven() {
        // A phone that never agreed has no value; @AppStorage and UserDefaults.integer read it as 0.
        let defaults = UserDefaults(suiteName: "AIConsentTests.\(UUID().uuidString)")!
        #expect(!AIConsent.isGiven(stored: defaults.integer(forKey: AIConsent.storageKey)))
        defaults.set(AIConsent.agreed, forKey: AIConsent.storageKey)
        #expect(AIConsent.isGiven(stored: defaults.integer(forKey: AIConsent.storageKey)))
    }

    @Test func signUpNoteNamesTheProvidersBothDocumentsAndRealPatientData() {
        let note = AIConsent.signUpNote(terms: URL(string: "https://example.com/terms"), privacy: URL(string: "https://example.com/privacy"))
        #expect(note.contains("OpenAI"))
        #expect(note.contains("DeepSeek"))
        #expect(note.contains("real patient"))
        #expect(note.contains("[Terms of Use](https://example.com/terms)"))
        #expect(note.contains("[Privacy Policy](https://example.com/privacy)"))
    }

    @Test func signUpNoteWithoutLinksKeepsTheTitles() {
        let note = AIConsent.signUpNote(terms: nil, privacy: nil)
        #expect(note.contains("Terms of Use and Privacy Policy"))
        #expect(!note.contains("]("))
    }

    /// Adding the terms raised the version, so a student who agreed to the AI-only wording is asked again.
    @Test func earlierAgreementAsksAgain() {
        #expect(AIConsent.currentVersion >= 2)
        #expect(!AIConsent.isGiven(stored: 1))
    }
}
