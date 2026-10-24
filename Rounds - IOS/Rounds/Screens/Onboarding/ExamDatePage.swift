import SwiftUI

/// "When is your Step 2 CK?": the next five months, each with how many weeks away it is, and
/// "After <last month>". The weeks are their own screen after it (CountdownPage). The page has no
/// Skip: "After" is the answer for no date yet. Only asked
/// when the goal is an exam.
struct ExamDatePage: View {
    var shown = true
    @AppStorage(ExamMonth.storageKey) private var stored = ""
    @AppStorage(StudyGoal.storageKey) private var goalStored = ""

    private let months = ExamMonth.upcoming()
    private var picked: ExamMonth? { ExamMonth(stored: stored) }

    private var title: String {
        switch StudyGoal(stored: goalStored) {
        case .shelf: "When is your next shelf?"
        case .osce: "When is your OSCE?"
        case let goal?: "When is your \(goal.label)?"
        case nil: "When is your exam?"
        }
    }

    var body: some View {
        OnboardingQuestion(title: title, shown: shown) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(Array(months.enumerated()), id: \.element) { i, m in
                    monthButton(m.shortName(), detail: m.away(), on: picked == m, order: i) { stored = m.stored }
                }
                monthButton("After \(months.last?.shortName() ?? "that")", detail: "Later", on: stored == ExamMonth.later,
                            order: months.count) { stored = ExamMonth.later }
            }
        }
        .animation(Springs.slide, value: stored)
    }

    private func monthButton(_ title: String, detail: String, on: Bool, order: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(.system(size: 16, weight: .semibold))
                Text(detail).font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(on ? Theme.accentSoft : Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(on ? Theme.accent : Theme.border, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(PressDownStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: on)
        .modifier(QuestionEntrance(order: order))
    }
}
