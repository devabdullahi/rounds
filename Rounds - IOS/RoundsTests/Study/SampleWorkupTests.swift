import Testing
@testable import Rounds

/// Onboarding's sample case after the interview: the script is complete, Continue's thresholds can
/// be reached, and the right call scores higher.
struct SampleWorkupTests {
    private let workup = SampleWorkup.soreThroat

    @Test func scriptIsComplete() {
        #expect(workup.maneuvers.count >= SampleWorkup.examsNeeded)
        #expect(workup.tests.count >= SampleWorkup.testsNeeded)
        #expect(workup.diagnoses.contains(workup.answer))
        #expect(Set(workup.maneuvers.map(\.id)).count == workup.maneuvers.count)
        #expect(Set(workup.tests.map(\.id)).count == workup.tests.count)
        #expect(workup.maneuvers.allSatisfy { !$0.finding.isEmpty })
        #expect(workup.tests.allSatisfy { !$0.result.isEmpty })
    }

    @Test func rightCallScoresHigher() throws {
        let pick = try #require(workup.diagnoses.first { $0 != workup.answer })
        #expect(workup.score(for: workup.answer) > workup.score(for: pick))
        #expect(workup.verdict(for: workup.answer) == "You said \(workup.answer)")
    }

    @Test(arguments: ["Strep throat", "Mono"])
    func shareTextCarriesTheScore(pick: String) {
        #expect(workup.shareText(for: pick).contains("\(workup.score(for: pick))/100"))
    }
}
