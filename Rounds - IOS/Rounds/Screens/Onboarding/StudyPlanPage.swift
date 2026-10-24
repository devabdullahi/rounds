import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Your plan
 *    0ms   title and stat tiles rise (ease-out)
 *  300ms   one bar per week grows, 50ms apart (ease-out)
 *  500ms   rows rise, 80ms apart
 * Reduce Motion: final state.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let bars = 0.3
    static let barGap = 0.05
}

/// "Your Step 2 CK plan": everything the student picked, read back as a plan they can see. Cases
/// by test day and minutes a day, a bar per week, then what each day and each case brings.
struct StudyPlanPage: View {
    var shown = true
    @AppStorage(SchoolYear.storageKey) private var yearStored = ""
    @AppStorage(StudyGoal.storageKey) private var goalStored = ""
    @AppStorage(ExamMonth.storageKey) private var examStored = ""
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    @AppStorage(DailyGoal.storageKey) private var dailyGoalStored = DailyGoal.default.rawValue
    @AppStorage(PracticeReminder.preferredKey) private var timeStored = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    private var goal: StudyGoal? { StudyGoal(stored: goalStored) }
    private var exam: ExamMonth? { ExamMonth(stored: examStored) }
    private var pace: DailyGoal { DailyGoal(stored: dailyGoalStored) }
    private var weeks: Int { exam?.weeksLeft() ?? 4 }
    private var total: Int { exam?.patients(perDay: pace.cases) ?? pace.cases * 7 * weeks }

    private var title: String {
        guard let goal, goal.debriefTips != nil else { return "Your Rounds plan" }
        return "Your \(goal.tipsName) plan"
    }

    /// "MS3 · Internal medicine · December": the picks behind the plan, in one line.
    private var subtitle: String {
        let focus = FocusSelection(stored: focusStored)
        return [SchoolYear(stored: yearStored)?.label, focus.isMix ? "A mix of everything" : focus.label, exam?.name()]
            .compactMap { $0 }.joined(separator: " · ")
    }

    /// Under the total, in words, so the number reads on its own: "patients you'll have worked up
    /// before Step 1, if you see 2 a day".
    private var totalLabel: String {
        let pace = "if you see \(self.pace.cases) a day"
        guard exam != nil else { return "patients you'll work up in \(weeks) weeks, \(pace)" }
        return "patients you'll have worked up before \(goal?.tipsName ?? "test day"), \(pace)"
    }

    private var rows: [(IconGlyph, String, String)] {
        var out: [(IconGlyph, String, String)] = [(.user, "Each day", "\(pace.cases) \(pace.cases == 1 ? "patient" : "patients")")]
        if let time = PracticeReminder(stored: timeStored) { out.append((.clock, "When", time.period)) }
        if let goal, goal.debriefTips != nil { out.append((.circleCheck, "After each case", "\(goal.tipsName) tip")) }
        out.append((.cards, "Your misses", "Become flashcards"))
        return out
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 28, weight: .bold)).tracking(-0.5).foregroundStyle(Theme.text)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle).font(.system(size: 15)).foregroundStyle(Theme.muted)
                }
                .padding(.top, 16)
                .rise(shown, at: 0, offset: 8)

                HStack(spacing: 10) {
                    stat("\(total)", totalLabel, dark: true)
                    stat("\(pace.cases * 10)", "min a day", dark: false)
                }
                .rise(shown, at: 0, offset: 8)

                weekChart
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack(spacing: 12) {
                        AppIcon(row.0, size: 18).foregroundStyle(Theme.accentText)
                            .frame(width: 34, height: 34)
                            .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text(row.1).foregroundStyle(Theme.muted)
                        Spacer()
                        Text(row.2).fontWeight(.semibold).foregroundStyle(Theme.text)
                    }
                    .font(.system(size: 15))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.border))
                    .accessibilityElement(children: .combine)
                    .modifier(QuestionEntrance(order: i + 1))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .onChange(of: shown, initial: true) { _, now in if now { grown = true } }
    }

    private func stat(_ value: String, _ label: String, dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 30, weight: .bold)).tracking(-1)
            Text(label).font(.system(size: 13)).opacity(dark ? 0.8 : 1)
        }
        .foregroundStyle(dark ? Theme.accentInk : Theme.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(dark ? AnyShapeStyle(Theme.welcomeGreen) : AnyShapeStyle(Theme.track), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// One bar per week, rising: the pace adding up toward test day.
    private var weekChart: some View {
        let count = min(weeks, 12)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(pace.cases * 7) patients a week").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(weeks) \(weeks == 1 ? "week" : "weeks")").font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            .foregroundStyle(Theme.text)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(i == 0 ? Theme.accent : Theme.accent.opacity(0.3))
                        .frame(height: grown || reduceMotion ? 28 + CGFloat(i) * (56 / CGFloat(max(count - 1, 1))) : 4)
                        .animation(reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: 0.6).delay(TIMING.bars + Double(i) * TIMING.barGap), value: grown)
                }
            }
            .frame(height: 88, alignment: .bottom)
        }
        .padding(14)
        .background(Theme.bg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pace.cases * 7) patients a week for \(weeks) weeks")
    }
}
