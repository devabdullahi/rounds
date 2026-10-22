import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Your plan
 *    0ms   ring track shows; ring fills to 90% (1000ms)
 *  300ms   the patient count ticks up to its total
 *  500ms   rows rise, 80ms apart
 * Reduce Motion: final state.
 * ───────────────────────────────────────────────────────── */

/// "Your plan for Step 2 CK": only what the student picked, read back as a plan. With an exam
/// month, the ring counts patients by test day; without one, it shows the daily pace.
struct StudyPlanPage: View {
    var shown = true
    @AppStorage(SchoolYear.storageKey) private var yearStored = ""
    @AppStorage(StudyGoal.storageKey) private var goalStored = ""
    @AppStorage(ExamMonth.storageKey) private var examStored = ""
    @AppStorage(DailyGoal.storageKey) private var dailyGoalStored = DailyGoal.default.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var goal: StudyGoal? { StudyGoal(stored: goalStored) }
    private var exam: ExamMonth? { ExamMonth(stored: examStored) }
    private var perDay: Int { DailyGoal(stored: dailyGoalStored).cases }

    private var title: String {
        switch goal {
        case .step1?, .step2CK?, .osce?: "Your plan for \(goal?.label ?? "")"
        case .shelf?: "Your plan for your shelves"
        default: "Your Rounds plan"
        }
    }

    private var rows: [(String, String)] {
        var out: [(String, String)] = []
        if let year = SchoolYear(stored: yearStored) { out.append(("Year", year.label)) }
        if let exam { out.append(("Test day", "\(exam.name()) · \(exam.weeksLeft()) weeks")) }
        out.append(("Each day", "\(perDay) patients"))
        return out
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 20)
            ZStack {
                Circle().stroke(Theme.track, lineWidth: 22)
                Circle()
                    .trim(from: 0, to: shown || reduceMotion ? 0.9 : 0)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 22, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .easeOut(duration: 1).delay(0.1), value: shown)
                VStack(spacing: 2) {
                    Text(exam.map { "\($0.patients(perDay: perDay))" } ?? "\(perDay)")
                        .font(.system(size: 46, weight: .bold)).tracking(-1)
                        .foregroundStyle(Theme.text)
                    Text(exam == nil ? "patients a day" : "patients by test day")
                        .font(.system(size: 14)).foregroundStyle(Theme.muted)
                }
            }
            .frame(width: 210, height: 210)
            .accessibilityElement(children: .combine)
            VStack(spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack {
                        Text(row.0).foregroundStyle(Theme.muted)
                        Spacer()
                        Text(row.1).fontWeight(.semibold).foregroundStyle(Theme.text)
                    }
                    .font(.system(size: 16))
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(Theme.track, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .modifier(QuestionEntrance(order: i + 1))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }
}
