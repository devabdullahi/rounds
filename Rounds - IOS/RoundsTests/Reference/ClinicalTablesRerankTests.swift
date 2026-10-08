import Foundation
import Testing
@testable import Rounds

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
