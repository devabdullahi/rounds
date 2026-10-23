import Testing
@testable import Rounds

/// The confidence answer: only 1–10 counts, and the reality check's headline reads it back.
struct DiagnosisConfidenceTests {
    @Test(arguments: [0, 11, -3])
    func outOfRangeIsNoAnswer(stored: Int) {
        #expect(DiagnosisConfidence(stored: stored) == nil)
    }

    @Test(arguments: [(7, "A 7 won't cut it."), (8, "Keep that 8 sharp."), (1, "A 1 won't cut it.")])
    func headlineReadsTheNumberBack(stored: Int, headline: String) throws {
        let confidence = try #require(DiagnosisConfidence(stored: stored))
        #expect(confidence.headline == headline)
    }
}
