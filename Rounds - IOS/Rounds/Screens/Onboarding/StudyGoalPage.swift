import SwiftUI

/// "What are you studying for?": the exams and other goals, one tap picks.
struct StudyGoalPage: View {
    @AppStorage(StudyGoal.storageKey) private var stored = ""

    var body: some View {
        OnboardingQuestion(title: "What are you studying for?") {
            ForEach(StudyGoal.allCases) { goal in
                ChoiceRow(title: goal.label, on: StudyGoal(stored: stored) == goal) { stored = goal.rawValue }
            }
        }
    }
}
