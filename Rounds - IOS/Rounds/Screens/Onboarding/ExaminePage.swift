import SwiftUI

/// Step 2 of the sample case: the real Exam tab with Dana's four exam rows. Each Examine shows its
/// finding under the row, red when it's abnormal, as in a case. Continue waits for all four.
struct ExaminePage: View {
    var shown = true
    var onFinished: () -> Void = {}

    private let workup = SampleWorkup.soreThroat
    @State private var done: [String] = []

    private var coach: String {
        switch done.count {
        case 0: "Tap Examine. Dana reacts like a real patient."
        case SampleWorkup.examsNeeded...: "Findings are saved for your grade."
        default: "Good. Keep going: \(SampleWorkup.examsNeeded - done.count) left."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                CoachStrip(step: 2, of: 4, text: coach)
                DemoCaseHeader(patient: workup.patient, mood: workup.mood, clock: "09:12", onTests: false)
                CountProgressCard(title: "Examined", done: done.count, total: workup.maneuvers.count, accessibilityNoun: "examined")
                Text("VITALS, THROAT AND NECK")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
                VStack(spacing: 0) {
                    ForEach(workup.maneuvers) { m in
                        row(m)
                        if m.id != workup.maneuvers.last?.id { Divider().padding(.leading, 16) }
                    }
                }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func row(_ m: SampleWorkup.Maneuver) -> some View {
        let isDone = done.contains(m.id)
        return Button { examine(m) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(m.title).font(.system(size: 16, weight: .medium))
                    Spacer()
                    ZStack {
                        if isDone {
                            AppIcon(.circleCheck, size: 22)
                                .foregroundStyle(Theme.accent)
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                        } else {
                            Text("Examine")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.accentText)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 32)
                                .background(Theme.accentSoft, in: Capsule())
                                .transition(.opacity)
                        }
                    }
                }
                if isDone {
                    Text(m.finding)
                        .font(.system(size: 14))
                        .foregroundStyle(m.isAbnormal ? Theme.warnText : Theme.dim)
                        .lineSpacing(2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(isDone)
        .sensoryFeedback(.impact(weight: .light), trigger: isDone)
        .accessibilityLabel(isDone ? "\(m.title), examined. \(m.finding)" : "Examine: \(m.title)")
    }

    private func examine(_ m: SampleWorkup.Maneuver) {
        withAnimation(Springs.pop) { done.append(m.id) }
        if done.count == SampleWorkup.examsNeeded { onFinished() }
    }
}
