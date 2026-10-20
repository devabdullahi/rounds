import SwiftUI

/// "How many cases a day?": the daily target Home counts toward.
struct DailyGoalPage: View {
    var shown = true
    @AppStorage(DailyGoal.storageKey) private var stored = DailyGoal.default.rawValue

    var body: some View {
        OnboardingQuestion(title: "How many cases a day?", glyph: .calendarCheck, shown: shown) {
            ForEach(Array(DailyGoal.allCases.enumerated()), id: \.element) { i, goal in
                ChoiceRow(title: goal.label, trailing: goal.duration, badge: String(goal.cases), tint: ChoiceRow.tint(i),
                          on: DailyGoal(stored: stored) == goal, order: i) {
                    stored = goal.rawValue
                }
            }
        }
    }
}
