import SwiftUI

/// "How many patients a day?": − and + step through the paces (1, 2, 3 or 5), and the card under
/// them shows what that adds up to: patients by test day with an exam month, otherwise a week.
struct PacePage: View {
    var shown = true
    @AppStorage(DailyGoal.storageKey) private var stored = DailyGoal.default.rawValue
    @AppStorage(ExamMonth.storageKey) private var examStored = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pace: DailyGoal { DailyGoal(stored: stored) }
    private var exam: ExamMonth? { ExamMonth(stored: examStored) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("How many patients a day?")
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 20)

            HStack {
                stepButton(.minus, label: "Fewer patients", by: -1)
                Spacer()
                VStack(spacing: 2) {
                    Text("\(pace.cases)")
                        .font(.system(size: 72, weight: .bold)).tracking(-2)
                        .contentTransition(.numericText(value: Double(pace.cases)))
                    Text(pace.cases == 1 ? "patient a day" : "patients a day")
                        .font(.system(size: 15)).foregroundStyle(Theme.muted)
                }
                .foregroundStyle(Theme.text)
                .accessibilityElement(children: .combine)
                Spacer()
                stepButton(.plus, label: "More patients", by: 1)
            }
            .padding(.top, 28)

            Text(pace.duration + " a day")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            totals
                .padding(.top, 24)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .animation(reduceMotion ? nil : Springs.pop, value: stored)
        .sensoryFeedback(.selection, trigger: stored)
    }

    private func stepButton(_ glyph: IconGlyph, label: String, by: Int) -> some View {
        let next = pace.stepped(by: by)
        return Button { if let next { stored = next.rawValue } } label: {
            AppIcon(glyph, size: 24)
                .foregroundStyle(by > 0 ? Theme.accentInk : Theme.text)
                .frame(width: 64, height: 64)
                .background(by > 0 ? AnyShapeStyle(Theme.accentFill) : AnyShapeStyle(Theme.track), in: Circle())
        }
        .buttonStyle(PressDownStyle())
        .disabled(next == nil)
        .opacity(next == nil ? 0.4 : 1)
        .accessibilityLabel(label)
    }

    /// What the pace adds up to, on the same dark card as the exam countdown.
    private var totals: some View {
        let weeks = exam?.weeksLeft() ?? 1
        let total = exam?.patients(perDay: pace.cases) ?? pace.cases * 7
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(total)").font(.system(size: 40, weight: .bold)).tracking(-1)
                    .contentTransition(.numericText(value: Double(total)))
                Text(exam == nil ? "patients a week" : "patients by test day").font(.system(size: 17, weight: .semibold))
            }
            if exam != nil {
                WeekBars(weeks: weeks).accessibilityHidden(true)
            }
            Text(pace.cases <= 1 ? "A steady start. You can raise it any time." : "One patient at a time. Change it any time in Settings.")
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
