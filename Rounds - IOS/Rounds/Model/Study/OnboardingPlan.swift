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

    /// A picked care setting rides on the Focus row ("Surgery · Clinic"), keeping the card at four rows.
    init(name: String? = nil, year: SchoolYear?, goal: StudyGoal?, focus: FocusSelection, setting: CareSetting = .any) {
        var rows: [Row] = []
        if let name = name.flatMap(ProfileName.clean) { rows.append(Row(title: "Name", value: name)) }
        if let year { rows.append(Row(title: "Year", value: year.label)) }
        if let goal { rows.append(Row(title: "Goal", value: goal.label)) }
        rows.append(Row(title: "Focus", value: setting == .any ? focus.label : "\(focus.label) · \(setting.label)"))
        self.rows = rows
    }
}
