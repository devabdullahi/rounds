import Foundation

/// The "Your Rounds are ready" summary: the student's onboarding answers read back as rows, so the
/// last question pays off before the account ask. Unanswered questions are left out.
struct OnboardingPlan: Equatable {
    struct Row: Equatable, Identifiable {
        let title: String
        let value: String
        var id: String { title }
    }

    let rows: [Row]

    init(year: SchoolYear?, goal: StudyGoal?, focus: FocusSelection, level: InterviewLevel?) {
        var rows: [Row] = []
        if let year { rows.append(Row(title: "Year", value: year.label)) }
        if let goal { rows.append(Row(title: "Goal", value: goal.label)) }
        rows.append(Row(title: "Focus", value: focus.label))
        if let level { rows.append(Row(title: "Level", value: level.label)) }
        self.rows = rows
    }
}
