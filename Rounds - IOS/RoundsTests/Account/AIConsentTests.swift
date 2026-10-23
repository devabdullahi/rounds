import Foundation
import Testing
@testable import Rounds

/// The AI consent's stored-version rules, and where it sits in onboarding.
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

    @Test func pointsNameTheProvidersAndRealPatientData() {
        let text = AIConsent.points.joined(separator: " ")
        #expect(text.contains("OpenAI"))
        #expect(text.contains("DeepSeek"))
        #expect(text.contains("real patient"))
        #expect(text.contains("not medical advice"))
        #expect(text.contains("isn't responsible for any diagnosis"))
    }

    @Test func noteAcceptsBothDocuments() {
        #expect(AIConsent.termsNote.contains("Terms of Use"))
        #expect(AIConsent.termsNote.contains("Privacy Policy"))
    }

    /// Adding the terms raised the version, so a student who agreed to the AI-only wording is asked again.
    @Test func earlierAgreementAsksAgain() {
        #expect(AIConsent.currentVersion >= 2)
        #expect(!AIConsent.isGiven(stored: 1))
    }
}
