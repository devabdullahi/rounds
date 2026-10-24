import Testing
@testable import Rounds

@Suite("Workup step hint")
struct WorkupStepTests {
    @Test("points at the next untouched step once the one before is underway", arguments: [
        (0, 0, 0, nil),
        (3, 0, 0, nil),
        (4, 0, 0, WorkupStep.examine),
        (12, 0, 0, .examine),
        (6, 1, 0, nil),
        (6, 2, 0, .tests),
        (0, 3, 0, .tests),
        (6, 2, 1, nil),
        (0, 0, 2, nil),
    ] as [(Int, Int, Int, WorkupStep?)])
    func hint(asked: Int, exam: Int, tests: Int, expected: WorkupStep?) {
        #expect(WorkupStep.hint(questionsAsked: asked, examDone: exam, testsDone: tests) == expected)
    }

    @Test func examineNudgeNamesTheFirstManeuverAndThePatient() throws {
        let n = try #require(WorkupStep.nudge(for: .examine, firstManeuver: "Observe his gait", sex: "M"))
        #expect(n.title == "Good history. Time to examine him.")
        #expect(n.detail == "Start with: observe his gait.")
    }

    @Test func nudgesWithoutAManeuverOrForOtherSteps() throws {
        let generic = try #require(WorkupStep.nudge(for: .examine, firstManeuver: nil, sex: "F"))
        #expect(generic.detail.contains("her chart"))
        #expect(WorkupStep.nudge(for: .tests, firstManeuver: nil, sex: "F")?.title == "Good exam. Time for tests.")
        #expect(WorkupStep.nudge(for: .ask, firstManeuver: "x", sex: "M") == nil)
    }
}
