import Foundation
import Testing
@testable import Rounds

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
