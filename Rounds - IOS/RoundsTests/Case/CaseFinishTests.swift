import Testing
@testable import Rounds

/// Leaving a graded case: the student lands on the ward, and the case flow can't be re-entered.
@MainActor
struct CaseFinishTests {
    @Test func finishingAGradedCaseReturnsToPatients() {
        let app = AppState(cases: nil, cards: nil)
        app.finishCase()
        #expect(app.activeCase == nil)
        #expect(app.returnToPatients)
    }
}
