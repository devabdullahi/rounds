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
