import Foundation
import Testing
@testable import Rounds

/// Parsing of NLM Clinical Table Search replies, from real response shapes.
@Suite("Clinical Tables condition search")
struct ClinicalTablesConditionSearchTests {
    private func parse(_ json: String, limit: Int = 4) throws -> [ConditionMatch] {
        try ClinicalTablesConditionSearch.matches(from: Data(json.utf8), limit: limit)
    }

    @Test func mapsNamesCodesAndSynonymsInOrder() throws {
        let matches = try parse("""
        [47,["2231","368"],{"icd10cm_codes":["J06.9","J18.9"],"synonyms":[["URI","URT infection"],["JSW"]]},
        [["Upper respiratory infection","Upper respiratory infection (URI)"],["Pneumonia","Pneumonia"]]]
        """)
        #expect(matches.map(\.code) == ["J06.9", "J18.9"])
        #expect(matches[0].name == "Upper respiratory infection")
        #expect(matches[0].synonyms == ["Upper respiratory infection (URI)", "URI", "URT infection"])
        // The consumer name repeats the primary name, so it isn't listed as a synonym.
        #expect(matches[1].synonyms == ["JSW"])
    }

    @Test func usesFirstOfSeveralCodes() throws {
        let matches = try parse("""
        [1,["6660"],{"icd10cm_codes":["T74.92XA, T74.92XD, T74.92XS"],"synonyms":[[]]},[["Child abuse"]]]
        """)
        #expect(matches.first?.code == "T74.92XA")
    }

    @Test func skipsConditionsWithoutACodeAndRepeatedCodes() throws {
        let matches = try parse("""
        [3,["1","2","3"],{"icd10cm_codes":[null,"I10","I10"],"synonyms":[null,[],[]]},
        [["No code"],["Hypertension"],["High blood pressure"]]]
        """)
        #expect(matches.map(\.name) == ["Hypertension"])
    }

    @Test func emptyReplyHasNoMatches() throws {
        #expect(try parse("[0,[],{},[]]").isEmpty)
    }

    @Test func respectsLimit() throws {
        let matches = try parse("""
        [3,["1","2","3"],{"icd10cm_codes":["A","B","C"],"synonyms":[[],[],[]]},[["One"],["Two"],["Three"]]]
        """, limit: 2)
        #expect(matches.count == 2)
    }

    @Test func malformedReplyThrows() {
        #expect(throws: (any Error).self) { try parse(#"{"error":"bad"}"#) }
    }
}

@Suite("Clinical Tables re-ranking")
struct ClinicalTablesRerankTests {
    private let apiOrder = [
        ConditionMatch(code: "J06.9", name: "Upper respiratory infection", synonyms: ["URI"]),
        ConditionMatch(code: "J18.9", name: "Pneumonia", synonyms: []),
        ConditionMatch(code: "J44.9", name: "Chronic obstructive pulmonary disease", synonyms: ["COPD"]),
        ConditionMatch(code: "I26.99", name: "Pulmonary embolism", synonyms: ["PE"]),
    ]

    @Test func nameStartingWithQueryComesFirst() {
        let ranked = ClinicalTablesConditionSearch.rerank(apiOrder, for: "pulm", limit: 4)
        #expect(ranked.map(\.code) == ["I26.99", "J44.9", "J06.9", "J18.9"])
    }

    @Test func keepsApiMatchesWeCannotExplainAfterOurs() {
        let ranked = ClinicalTablesConditionSearch.rerank(apiOrder, for: "pulm", limit: 3)
        #expect(ranked.map(\.code) == ["I26.99", "J44.9", "J06.9"])
    }
}

@Suite("Clinical Tables display names")
struct ClinicalTablesNameTests {
    @Test func invertedNamesAreRewrittenAndKeptAsSynonyms() throws {
        let matches = try ClinicalTablesConditionSearch.matches(from: Data("""
        [1,["1"],{"icd10cm_codes":["J84.10"],"synonyms":[["pulmonary fibrosis"]]},[["Pulmonary fibrosis - interstitial","Pulmonary fibrosis - interstitial"]]]
        """.utf8), limit: 4)
        #expect(matches.first?.name == "Interstitial pulmonary fibrosis")
        #expect(matches.first?.synonyms.contains("Pulmonary fibrosis - interstitial") == true)
    }
}
