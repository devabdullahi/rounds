import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Reality check
 *
 *    0ms   label, headline and line rise, y 8 → 0 (ease-out)
 *  300ms   the dots fill in, one row (two weeks at one a day) every 50ms (ease-out)
 * Reduce Motion: all the dots, still.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let dots = 0.3
}

/// Tough love after the confidence and pace questions, short enough to read in a glance and built
/// only from true things: the student's own number, their exam month and the pace they just picked
/// (it comes after PacePage so the patient count is theirs, not a default). Only shown with an exam month.
struct RealityCheckPage: View {
    var shown = true
    @AppStorage(DiagnosisConfidence.storageKey) private var confidenceStored = 0
    @AppStorage(ExamMonth.storageKey) private var examStored = ""
    @AppStorage(DailyGoal.storageKey) private var dailyGoalStored = DailyGoal.default.rawValue
    @State private var drawn = false

    private var exam: ExamMonth? { ExamMonth(stored: examStored) }
    private var perDay: Int { DailyGoal(stored: dailyGoalStored).cases }
    private var total: Int { exam?.patients(perDay: perDay) ?? perDay * 7 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("REALITY CHECK")
                .font(.system(size: 13, weight: .heavy)).tracking(1)
                .foregroundStyle(Theme.warnText)
                .rise(shown, at: 0, offset: 8)
            Text(DiagnosisConfidence(stored: confidenceStored)?.headline ?? "Your exam is closer than it feels.")
                .font(.system(size: 30, weight: .bold)).tracking(-0.5)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .rise(shown, at: 0, offset: 8)
                .accessibilityAddTraits(.isHeader)
            Text("\(exam?.weeksLeft() ?? 0) weeks to go, and rotations rarely grade every case.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.dim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .rise(shown, at: 0, offset: 8)

            chart
                .padding(16)
                .background(Theme.track, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.top, 22)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .onChange(of: shown, initial: true) { _, now in if now { drawn = true } }
    }

    /// The patient count as dots, one per graded case: a number the student can see, built from
    /// their own pace and exam month.
    private var chart: some View {
        VStack(alignment: .leading, spacing: 12) {
            (Text("\(total) graded cases").bold() + Text(" by \(exam?.name() ?? "test day")"))
                .font(.system(size: 16))
                .foregroundStyle(Theme.text)
            CaseDots(count: total, shown: drawn, delay: TIMING.dots)
            Text("One dot per patient, at \(perDay) a day.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(total) graded cases by \(exam?.name() ?? "test day"), at \(perDay) a day.")
    }
}
