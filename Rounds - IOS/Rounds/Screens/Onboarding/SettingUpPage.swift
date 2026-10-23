import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Setting up your practice (moves on by itself)
 *
 *    0ms   ring starts filling 0 → 100% (2400ms, ease-in-out)
 *  300ms   step 1 rises in with a spinner; it turns to a check at 900ms
 *  900ms   step 2 in; check at 1500ms
 * 1500ms   step 3 in; check at 2100ms
 * 2700ms   onDone (the carousel moves to "Your plan")
 * Reduce Motion: ring full and every step checked at once; onDone after 1200ms.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let ring = 2.4
    static let firstStep = 0.3
    static let stepGap = 0.6
    static let done = 2.7
    static let doneReduced = 1.2
}

/// A short beat between the questions and the plan, listing only what the app really does with the
/// answers: the patients it picks, the exam tips in each debrief, the daily goal.
struct SettingUpPage: View {
    var shown = true
    var onDone: () -> Void = {}
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    @AppStorage(StudyGoal.storageKey) private var goalStored = ""
    @AppStorage(DailyGoal.storageKey) private var dailyGoalStored = DailyGoal.default.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var filled = false
    /// Steps shown so far, and how many of them are checked.
    @State private var visible = 0
    @State private var checked = 0
    @State private var finished = false

    private var steps: [String] {
        let focus = FocusSelection(stored: focusStored)
        let goal = StudyGoal(stored: goalStored)
        let perDay = DailyGoal(stored: dailyGoalStored).cases
        return [
            focus.isMix ? "Picking patients from every rotation" : "Picking \(focus.label) patients",
            goal?.debriefTips != nil ? "Turning on \(goal?.tipsName ?? "exam") tips in your debriefs" : "Lining up an attending's feedback",
            "Setting your goal: \(perDay) \(perDay == 1 ? "patient" : "patients") a day",
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(Theme.track, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: filled ? 1 : 0)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                AppIcon(.brandMark, size: 56).foregroundStyle(Theme.accent)
            }
            .frame(width: 180, height: 180)
            .accessibilityHidden(true)

            Text("Setting up your practice…")
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.4)
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
                .padding(.top, 32)
                .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    HStack(spacing: 12) {
                        ZStack {
                            if i < checked {
                                AppIcon(.check, size: 13)
                                    .foregroundStyle(Theme.accentInk)
                                    .frame(width: 22, height: 22)
                                    .background(Theme.accentFill, in: Circle())
                                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                            } else {
                                ProgressView().controlSize(.small).tint(Theme.accent)
                            }
                        }
                        .frame(width: 22, height: 22)
                        Text(step).font(.system(size: 16)).foregroundStyle(Theme.text)
                    }
                    .opacity(i < visible ? 1 : 0)
                    .offset(y: i < visible ? 0 : 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 26)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Setting up your practice. " + steps.joined(separator: ". "))
            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .task(id: shown) { if shown { await play() } }
    }

    private func play() async {
        guard !finished else { return }
        if reduceMotion {
            filled = true; visible = steps.count; checked = steps.count
            try? await Task.sleep(for: .seconds(TIMING.doneReduced))
        } else {
            withAnimation(.easeInOut(duration: TIMING.ring)) { filled = true }
            var at = 0.0
            for i in steps.indices {
                let start = TIMING.firstStep + Double(i) * TIMING.stepGap
                try? await Task.sleep(for: .seconds(start - at)); at = start
                withAnimation(Springs.slide) { visible = i + 1 }
                try? await Task.sleep(for: .seconds(TIMING.stepGap)); at += TIMING.stepGap
                withAnimation(Springs.pop) { checked = i + 1 }
            }
            try? await Task.sleep(for: .seconds(max(0, TIMING.done - at)))
        }
        guard !Task.isCancelled else { return }
        finished = true
        onDone()
    }
}
