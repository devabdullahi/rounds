import SwiftUI

/// "How many cases a day?": the daily target Home counts toward.
struct DailyGoalPage: View {
    @AppStorage(DailyGoal.storageKey) private var stored = DailyGoal.default.rawValue

    var body: some View {
        OnboardingQuestion(title: "How many cases a day?") {
            ForEach(DailyGoal.allCases) { goal in
                ChoiceRow(title: goal.label, trailing: goal.duration, on: DailyGoal(stored: stored) == goal) {
                    stored = goal.rawValue
                }
            }
        }
    }
}
