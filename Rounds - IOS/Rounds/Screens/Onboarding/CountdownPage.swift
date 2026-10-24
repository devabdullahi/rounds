import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Weeks until the exam
 *
 *    0ms   label and the big number rise, y 8 → 0 (ease-out)
 *  200ms   one block per week rises in, 40ms apart (ease-out)
 *  700ms   "We'll plan every week around it." rises
 * Reduce Motion: final state.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let blocks = 0.2
    static let blockGap = 0.04
    static let line = 0.7
}

/// The exam month made concrete, on its own screen: weeks until the exam as a big number and one
/// block per week, this week filled and the exam week outlined. No case math here: the pace isn't
/// picked yet, so the total waits for the plan (StudyPlanPage). Only shown with an exam month.
struct CountdownPage: View {
    var shown = true
    @AppStorage(ExamMonth.storageKey) private var examStored = ""
    @AppStorage(StudyGoal.storageKey) private var goalStored = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    private var exam: ExamMonth? { ExamMonth(stored: examStored) }
    private var weeks: Int { exam?.weeksLeft() ?? 1 }
    private var examName: String { StudyGoal(stored: goalStored)?.tipsName ?? "your exam" }
    /// Past this many weeks the blocks would be crumbs, so the grid stops at four rows.
    private static let mostBlocks = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            Text("\(examName) · \(exam?.name() ?? "")")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .rise(shown, at: 0, offset: 8)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(weeks)").font(.system(size: 72, weight: .bold)).tracking(-2)
                Text(weeks == 1 ? "week until \(examName)" : "weeks until \(examName)")
                    .font(.system(size: 24, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.text)
            .rise(shown, at: 0, offset: 8)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            blocks
                .padding(14)
                .background(Theme.bg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.top, 24)

            Text("We\u{2019}ll plan every week around it.")
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

    private var blocks: some View {
        let count = min(weeks, Self.mostBlocks)
        return VStack(spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<count, id: \.self) { i in
                    block(i, last: i == count - 1)
                        .opacity(grown || reduceMotion ? 1 : 0)
                        .offset(y: grown || reduceMotion ? 0 : 6)
                        .animation(reduceMotion ? nil : .timingCurve(0.23, 1, 0.32, 1, duration: 0.45)
                            .delay(TIMING.blocks + Double(i) * TIMING.blockGap), value: grown)
                }
            }
            HStack {
                legend(fill: Theme.accent, outline: false, "This week")
                Spacer()
                legend(fill: .clear, outline: true, "\(examName) week")
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(weeks) weeks: this week first, \(examName) in the last one")
    }

    /// Week `i`: this week filled, the exam week outlined, the ones between soft.
    private func block(_ i: Int, last: Bool) -> some View {
        let now = i == 0 && !last
        return RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(now ? Theme.accent : last ? Theme.surface : Theme.accentSoft)
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(last ? Theme.accent : .clear, lineWidth: 2))
            .aspectRatio(1, contentMode: .fit)
    }

    private func legend(fill: Color, outline: Bool, _ title: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(fill)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(outline ? Theme.accent : .clear, lineWidth: 1.5))
                .frame(width: 12, height: 12)
            Text(title)
        }
    }
}
