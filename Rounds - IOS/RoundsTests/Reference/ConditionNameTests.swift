import Testing
@testable import Rounds

@Suite("Condition names and match hints")
struct ConditionNameTests {
    @Test(arguments: [
        ("Pulmonary fibrosis - interstitial", "Interstitial pulmonary fibrosis"),
        ("Pneumonia - aspiration", "Aspiration pneumonia"),
        ("COPD - severe", "Severe COPD"),
        ("Pulmonary embolism", "Pulmonary embolism"),
        ("A - ", "A - "),
    ])
    func indexNamesReadClinically(listed: String, expected: String) {
        #expect(ReferenceMatching.uninverted(listed) == expected)
    }

    private let embolism = ConditionMatch(code: "I26.99", name: "Pulmonary embolism", synonyms: ["PE", "lung embolism"])

    @Test func synonymExplainsAMatchTheNameDoesNot() {
        #expect(ReferenceMatching.matchedSynonym("pe", in: embolism) == "PE")
        #expect(ReferenceMatching.matchedSynonym("lung", in: embolism) == "lung embolism")
    }

    @Test func noHintWhenTheNameMatches() {
        #expect(ReferenceMatching.matchedSynonym("pulm", in: embolism) == nil)
        #expect(ReferenceMatching.matchedSynonym("emb", in: embolism) == nil)
    }
}
