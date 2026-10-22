import Testing
@testable import Rounds

/// What onboarding promises about the debrief must match the server's exam lens
/// (`case-session/lens.ts`): a lens for the four exams, none for the rest.
struct StudyGoalTests {
    @Test(arguments: [StudyGoal.step1, .step2CK, .shelf, .osce])
    func examsPromiseDebriefTips(goal: StudyGoal) {
        #expect(goal.debriefTips != nil)
    }

    @Test(arguments: [StudyGoal.other, .practicing])
    func otherGoalsPromiseNoTips(goal: StudyGoal) {
        #expect(goal.debriefTips == nil)
    }
}
