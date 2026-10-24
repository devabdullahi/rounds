import Foundation
import Testing
@testable import Rounds

/// The case clock: a limit of 0 minutes is no limit, so a case never opens on a red 00:00.
@MainActor
struct CaseClockTests {
    private func session(minutes: Int) -> CaseSession {
        CaseSession(clinical: ClinicalCase(bed: "X1", name: "Test Patient", age: 40, sex: "F", setting: "", quote: "",
                                           demeanor: "", complaint: "", vitals: [], task: "", minutes: minutes,
                                           suggestedQuestions: [], exam: [], tests: [], clerkship: nil, system: nil,
                                           keyHistoryTotal: 0),
                    service: UnusedCaseService())
    }

    @Test("timed only with a limit above zero", arguments: [(0, false), (5, true), (10, true)])
    func timedOnlyWithALimit(minutes: Int, timed: Bool) {
        #expect(session(minutes: minutes).isTimed == timed)
    }

    @Test func zeroSetLaterIsStillUntimed() {
        let s = session(minutes: 10)
        s.timeLimitMinutes = 0
        #expect(!s.isTimed)
    }
}
