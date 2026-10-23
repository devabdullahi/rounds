import SwiftUI

/// "Save your plan": the plan the student just built, in three lines, so it's clear what signing
/// up keeps, then Continue with Apple or Google (the only ways to sign up).
struct AccountPage: View {
    var busy: SocialProvider?
    let onSelect: (SocialProvider) -> Void

    @AppStorage(StudyGoal.storageKey) private var goalStored = ""
    @AppStorage(ExamMonth.storageKey) private var examStored = ""
    @AppStorage(DailyGoal.storageKey) private var dailyGoalStored = DailyGoal.default.rawValue
    @AppStorage(PracticeReminder.preferredKey) private var timeStored = ""

    /// The picks behind the plan, skipping any the student didn't answer.
    private var lines: [(IconGlyph, String)] {
        let pace = DailyGoal(stored: dailyGoalStored).cases
        var out: [(IconGlyph, String)] = []
        if let goal = StudyGoal(stored: goalStored) {
            let month = ExamMonth(stored: examStored).map { " · \($0.name())" } ?? ""
            out.append((.target, goal.label + month))
        }
        out.append((.user, "\(pace) \(pace == 1 ? "patient" : "patients") a day"))
        if let time = PracticeReminder(stored: timeStored) { out.append((.clock, time.period)) }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Save your plan")
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(spacing: 12) {
                        AppIcon(line.0, size: 18).foregroundStyle(Theme.accentText)
                            .frame(width: 34, height: 34)
                            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityHidden(true)
                        Text(line.1).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.text)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.border))
            .padding(.top, 24)
            Spacer(minLength: 0)
            ProviderButtons(busy: busy, onSelect: onSelect)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
}
