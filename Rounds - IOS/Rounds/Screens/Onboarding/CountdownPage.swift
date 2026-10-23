import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Weeks to go
 *
 *    0ms   label and the big number rise, y 8 → 0 (ease-out)
 *  200ms   one bar per week grows from the baseline, 60ms apart (ease-out)
 *  700ms   "N cases at M a day" rises
 * Reduce Motion: final state.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let bars = 0.2
    static let barGap = 0.06
    static let line = 0.7
}

/// The exam month made concrete, on its own screen: weeks to go as a big number, a bar per week,
/// and how many cases the student's pace adds up to by then. Only shown with an exam month.
struct CountdownPage: View {
    var shown = true
    @AppStorage(ExamMonth.storageKey) private var examStored = ""
    @AppStorage(StudyGoal.storageKey) private var goalStored = ""
    @AppStorage(DailyGoal.storageKey) private var dailyGoalStored = DailyGoal.default.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    private var exam: ExamMonth? { ExamMonth(stored: examStored) }
    private var weeks: Int { exam?.weeksLeft() ?? 1 }
    private var perDay: Int { DailyGoal(stored: dailyGoalStored).cases }
    /// Past this many weeks the bars would be slivers, so the chart stops here.
    private static let mostBars = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            Text("Your \(StudyGoal(stored: goalStored)?.tipsName ?? "exam") · \(exam?.name() ?? "")")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .rise(shown, at: 0, offset: 8)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(weeks)").font(.system(size: 72, weight: .bold)).tracking(-2)
                Text(weeks == 1 ? "week to go" : "weeks to go").font(.system(size: 24, weight: .bold))
            }
            .foregroundStyle(Theme.text)
            .rise(shown, at: 0, offset: 8)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            bars
                .padding(16)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.top, 24)

            Text("\(exam?.patients(perDay: perDay) ?? perDay * 7) cases at \(perDay) a day.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)
                .padding(.top, 16)
                .rise(shown, at: TIMING.line, offset: 8)
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .onChange(of: shown, initial: true) { _, now in if now { grown = true } }
    }

    private var bars: some View {
        let count = min(weeks, Self.mostBars)
        return VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<count, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(i == 0 ? Theme.accent : Theme.accent.opacity(0.3))
                        .frame(height: grown || reduceMotion ? 40 + CGFloat(i) * (130 / CGFloat(max(count - 1, 1))) : 4)
                        .animation(reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: 0.6).delay(TIMING.bars + Double(i) * TIMING.barGap), value: grown)
                }
            }
            .frame(height: 176, alignment: .bottom)
            HStack {
                Text("Now")
                Spacer()
                Text(exam?.name() ?? "Test day")
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.muted)
        }
        .accessibilityHidden(true)
    }
}
