import SwiftUI

/// "When is your Step 2 CK?": the next five months and "Later", and a countdown card that turns
/// the pick into weeks and patients. "Not sure yet" (the page's Skip) leaves it unset. Only asked
/// when the goal is an exam.
struct ExamDatePage: View {
    var shown = true
    @AppStorage(ExamMonth.storageKey) private var stored = ""
    @AppStorage(StudyGoal.storageKey) private var goalStored = ""
    @AppStorage(DailyGoal.storageKey) private var dailyGoalStored = DailyGoal.default.rawValue

    private let months = ExamMonth.upcoming()
    private var picked: ExamMonth? { ExamMonth(stored: stored) }
    private var perDay: Int { DailyGoal(stored: dailyGoalStored).cases }

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
                    monthButton(m.shortName(), detail: String(m.year), on: picked == m, order: i) { stored = m.stored }
                }
                monthButton("Later", detail: " ", on: stored == ExamMonth.later, order: months.count) { stored = ExamMonth.later }
            }
            if let picked {
                countdown(picked)
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(Springs.slide, value: stored)
    }

    private func monthButton(_ title: String, detail: String, on: Bool, order: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(.system(size: 16, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(Theme.muted)
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

    private func countdown(_ month: ExamMonth) -> some View {
        let weeks = month.weeksLeft()
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(weeks)").font(.system(size: 40, weight: .bold)).tracking(-1).contentTransition(.numericText())
                Text(weeks == 1 ? "week to go" : "weeks to go").font(.system(size: 17, weight: .semibold))
            }
            WeekBars(weeks: weeks)
                .id(weeks)
                .accessibilityHidden(true)
            Text("\(month.patients(perDay: perDay)) cases at \(perDay) a day")
                .font(.system(size: 15))
                .opacity(0.9)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.accentInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.welcomeGreen, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
