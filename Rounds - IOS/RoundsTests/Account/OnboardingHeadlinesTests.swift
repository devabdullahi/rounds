import Testing
@testable import Rounds

/// The value pages say the student's answers back, and fall back to the general line without them.
struct OnboardingHeadlinesTests {
    @Test func withoutAnswersEveryPageKeepsItsGeneralLine() {
        let none = OnboardingHeadlines()
        #expect(none.examReady == "Walk Into Your\nExam Ready")
        #expect(none.promise == "Think Like\na Doctor")
        #expect(none.missCards == "Learn From\nEvery Miss")
        #expect(none.progress == "See Where You're\nGetting Better")
    }

    @Test(arguments: [
        (StudyGoal.step1, "Walk Into Step 1\nReady"),
        (.step2CK, "Walk Into Step 2 CK\nReady"),
        (.shelf, "Walk Into Your\nShelves Ready"),
        (.osce, "Walk Into Your\nOSCEs Ready"),
        (.practicing, "Walk Into Your\nExam Ready"),
    ])
    func theExamPageNamesTheirExam(goal: StudyGoal, headline: String) {
        #expect(OnboardingHeadlines(goal: goal).examReady == headline)
    }

    @Test func onlyTheFirstNameIsUsed() {
        let named = OnboardingHeadlines(name: "  Sam   Lee ")
        #expect(named.promise == "Think Like a\nDoctor, Sam")
        #expect(named.progress == "Sam, See Where\nYou're Improving")
        #expect(OnboardingHeadlines(name: "   ").promise == "Think Like\na Doctor")
    }

    @Test func oneShortFocusIsNamedAndAnythingElseIsNot() {
        #expect(OnboardingHeadlines(focus: FocusSelection([.rotation(.surgery)])).missCards == "Learn From Every\nSurgery Miss")
        #expect(OnboardingHeadlines(focus: FocusSelection([.rotation(.surgery), .rotation(.pediatrics)])).missCards == "Learn From\nEvery Miss")
        #expect(OnboardingHeadlines(focus: FocusSelection()).missCards == "Learn From\nEvery Miss")
    }
}
