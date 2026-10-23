import Testing
@testable import Rounds

/// The line under the score when a right call lifted it to the passing floor.
struct GradeFloorNoteTests {
    private func grade(floor: Bool, workup: (got: Int, max: Int)?) -> Grade {
        Grade(score: 70, diagnosisCorrect: true, diagnosis: "Strep throat", verdict: "Right call", ratingDelta: 5, rating: 1200,
              feedback: [], missedRedFlags: [], workupPoints: workup, floorApplied: floor)
    }

    @Test func liftedScoreShowsTheWorkupsOwnPoints() {
        #expect(grade(floor: true, workup: (got: 22, max: 65)).floorNote == "Right call. Your workup earned 22 of 65.")
    }

    @Test func noNoteWithoutTheFloorOrOnOlderGrades() {
        #expect(grade(floor: false, workup: (got: 50, max: 65)).floorNote == nil)
        #expect(grade(floor: true, workup: nil).floorNote == nil)
    }
}
