import Foundation
import Testing
@testable import Rounds

/// Onboarding's pure rules: the hold-to-promise heart, the stored answers and the plan built from them.
struct OnboardingTests {
    @Test func holdingTheFullTimeCompletes() {
        let frame = 1.0 / 60
        var heart = HoldToCommit()
        var frames = 0
        while !heart.isDone && frames < 1_000 {
            heart.advance(by: frame, holding: true)
            frames += 1
        }
        #expect(heart.isDone && heart.progress == 1)
        #expect(abs(Double(frames) - HoldToCommit.fillSeconds / frame) <= 1)
    }

    @Test func lettingGoEarlyDrainsBackToEmpty() {
        var heart = HoldToCommit()
        heart.advance(by: 0.8, holding: true)
        #expect(heart.progress > 0.4 && heart.progress < 0.6)
        heart.advance(by: 0.4, holding: false)
        #expect(heart.progress == 0)
        #expect(!heart.isDone)
        #expect(heart.isSettled(holding: false))
    }

    @Test func aFullHeartStaysFull() {
        var heart = HoldToCommit()
        heart.advance(by: HoldToCommit.fillSeconds, holding: true)
        #expect(heart.advance(by: 1, holding: false) == false)
        #expect(heart.progress == 1)
    }

    @Test(arguments: [(0.0, 0), (0.3, 1), (0.55, 2), (0.8, 3), (1.2, 4)])
    func quarterMarks(held: Double, quarter: Int) {
        var heart = HoldToCommit()
        heart.advance(by: held * HoldToCommit.fillSeconds, holding: true)
        #expect(heart.quarter == quarter)
    }

    @Test func voiceOverCanCompleteWithoutHolding() {
        var heart = HoldToCommit()
        heart.complete()
        #expect(heart.isDone && heart.progress == 1)
    }

    @Test(arguments: StudyGoal.allCases)
    func studyGoalRoundTrips(goal: StudyGoal) {
        #expect(StudyGoal(stored: goal.rawValue) == goal)
    }

    @Test func unknownStudyGoalReadsAsNone() {
        #expect(StudyGoal(stored: "") == nil)
        #expect(StudyGoal(stored: "mcat") == nil)
    }

    @Test(arguments: SchoolYear.allCases)
    func schoolYearRoundTrips(year: SchoolYear) {
        #expect(SchoolYear(stored: year.rawValue) == year)
    }

    @Test(arguments: InterviewLevel.allCases)
    func interviewLevelRoundTrips(level: InterviewLevel) {
        #expect(InterviewLevel(stored: level.rawValue) == level)
    }

    @Test func unknownAnswersReadAsNone() {
        #expect(SchoolYear(stored: "") == nil)
        #expect(SchoolYear(stored: "pgy1") == nil)
        #expect(InterviewLevel(stored: "") == nil)
    }

    @Test func levelsLightMoreBarsAsTheyRise() {
        #expect(InterviewLevel.allCases.map(\.bars) == [1, 2, 3])
    }

    @Test(arguments: [(StudyGoal.step2CK, "Step 2 CK"), (.osce, "OSCEs"), (.practicing, "Exam day"), (.other, "Exam day")])
    func examDayTagNamesRealExams(goal: StudyGoal, tag: String) {
        #expect(goal.examDayTag == tag)
    }

    @Test func planReadsEveryAnswerBack() {
        let plan = OnboardingPlan(year: .ms3, goal: .step2CK,
                                  focus: FocusSelection([.rotation(.surgery)]), level: .gettingThere)
        #expect(plan.rows.map(\.title) == ["Year", "Goal", "Focus", "Level"])
        #expect(plan.rows.map(\.value) == ["MS3", "Step 2 CK", "Surgery", "Getting there"])
    }

    @Test func planLeavesOutUnansweredQuestions() {
        let plan = OnboardingPlan(year: nil, goal: nil, focus: FocusSelection(), level: nil)
        #expect(plan.rows == [OnboardingPlan.Row(title: "Focus", value: "Mixed cases")])
    }
}
