import Testing
@testable import Rounds

@Suite("Condition search ranking")
struct ConditionRankingTests {
    let catalog = MockConditionSearch.catalog

    @Test func nameStartingWithQueryRanksFirst() {
        let results = ReferenceMatching.rankConditions("pulm", in: catalog, limit: 4)
        #expect(results.first?.code == "I26.99")
    }

    @Test func synonymsMatch() {
        let results = ReferenceMatching.rankConditions("inferior stemi", in: catalog, limit: 4)
        #expect(results.first?.code == "I21.19")
    }

    @Test func caseAndAccentDoNotMatter() {
        let lower = ReferenceMatching.rankConditions("gerd", in: catalog, limit: 4)
        let upper = ReferenceMatching.rankConditions("GÉRD", in: catalog, limit: 4)
        #expect(lower == upper)
        #expect(lower.first?.code == "K21.9")
    }

    @Test(arguments: ["", "s", "  "])
    func tooShortQueriesReturnNothing(query: String) {
        #expect(ReferenceMatching.rankConditions(query, in: catalog, limit: 4).isEmpty)
    }

    @Test func respectsLimit() {
        #expect(ReferenceMatching.rankConditions("ac", in: catalog, limit: 2).count <= 2)
    }

    @Test func unknownTextReturnsNothing() {
        #expect(ReferenceMatching.rankConditions("zzzz", in: catalog, limit: 4).isEmpty)
    }
}

@Suite("Drug recognition")
struct DrugRecognitionTests {
    let catalog = MockDrugRecognizer.catalog

    func names(_ text: String) -> [String] {
        ReferenceMatching.recognizeDrugs(in: text, catalog: catalog).map(\.name)
    }

    @Test func findsDrugsInOrderOfAppearance() {
        #expect(names("Give heparin, then aspirin 325 mg") == ["Heparin", "Aspirin"])
    }

    @Test(arguments: [
        ("ASA 325 chewed", "Aspirin"),
        ("start nitro SL", "Nitroglycerin"),
        ("unfractionated heparin bolus", "Heparin"),
        ("O2 if sats < 90", "Oxygen"),
    ])
    func recognisesAliases(text: String, expected: String) {
        #expect(names(text) == [expected])
    }

    @Test func matchesWholeWordsOnly() {
        // "asa" inside "nasal" and "o2" inside "co2" must not count.
        #expect(names("nasal cannula, check CO2").isEmpty)
    }

    @Test func listsEachDrugOnce() {
        #expect(names("aspirin now, aspirin daily") == ["Aspirin"])
    }
}

@Suite("Mock reference services")
struct MockReferenceServiceTests {
    @Test func debriefFindsReadingForTheCaseDiagnosis() async throws {
        let topics = try await MockHealthTopics().topics(for: "Inferior STEMI")
        #expect(topics.map(\.title) == ["Heart Attack"])
        #expect(topics.first?.url.host() == "medlineplus.gov")
    }

    @Test func unknownDiagnosisHasNoReading() async throws {
        #expect(try await MockHealthTopics().topics(for: "Something rare").isEmpty)
    }

    @Test func authoringHelpersAnswerForTheChestPainCase() async throws {
        let facts = try await MockDiseaseFacts().facts(forCode: "I21.19")
        #expect(facts?.redFlags.isEmpty == false)
        let patient = try await MockSyntheticPatients().patient(forCode: "I21.19")
        #expect(patient.age == 54)
        let ddx = try await MockDifferentialChecker().differential(for: ["chest pain", "sweating"])
        #expect(ddx.first?.name == "STEMI")
    }
}

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
