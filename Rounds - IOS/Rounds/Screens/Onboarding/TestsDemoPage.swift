import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Sample tests (per Order tap)
 *
 *    0ms   tests-taken bar springs; the row leaves "Order more"; a result card enters
 *          above it, scale 0.95 → 1, showing "Pending" with a spinner
 *  700ms   "Pending" swaps for "Resulted"; the result fades in (red when abnormal)
 * Reduce Motion: the result shows at once.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let result: Duration = .milliseconds(700)
}

/// Step 3 of the sample case: the real Tests tab. Order a test and its result lands in a card, as
/// in a case. Continue waits for two tests.
struct TestsDemoPage: View {
    var shown = true
    var onFinished: () -> Void = {}

    private let workup = SampleWorkup.soreThroat
    @State private var ordered: [String] = []
    @State private var resulted: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var coach: String {
        switch ordered.count {
        case 0: "Order a test. Results come back in seconds."
        case 1: "Red means abnormal. Order one more."
        default: "That's enough to make the call."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                CoachStrip(step: 3, of: 4, text: coach)
                DemoCaseHeader(patient: workup.patient, mood: workup.mood, clock: "08:40", onTests: true)
                CountProgressCard(title: "Tests taken", done: ordered.count, total: workup.tests.count, accessibilityNoun: "taken")
                ForEach(ordered, id: \.self) { id in
                    if let t = workup.tests.first(where: { $0.id == id }) { resultCard(t) }
                }
                let left = workup.tests.filter { !ordered.contains($0.id) }
                if !left.isEmpty {
                    Text("ORDER MORE")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 4)
                    VStack(spacing: 0) {
                        ForEach(left) { t in
                            orderRow(t)
                            if t.id != left.last?.id { Divider().padding(.leading, 16) }
                        }
                    }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .animation(reduceMotion ? nil : Springs.card, value: ordered)
        }
        .scrollIndicators(.hidden)
    }

    private func resultCard(_ t: SampleWorkup.Test) -> some View {
        let ready = resulted.contains(t.id)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t.name).font(.system(size: 17, weight: .semibold))
                Spacer()
                if ready {
                    Pill(text: "Resulted", fg: Theme.dim, bg: Theme.track)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                } else {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini).tint(Theme.muted)
                        Text("Pending")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                }
            }
            Text(ready ? t.result : "Waiting on the result…")
                .font(.system(size: 15))
                .foregroundStyle(ready ? (t.isAbnormal ? Theme.warnText : Theme.text) : Theme.muted)
                .contentTransition(.opacity)
        }
        .foregroundStyle(Theme.text)
        .card()
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .animation(Springs.card, value: ready)
        .accessibilityElement(children: .combine)
    }

    private func orderRow(_ t: SampleWorkup.Test) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(t.name).font(.system(size: 16, weight: .medium))
                Text(t.kind).font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button("Order") { order(t) }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .padding(.horizontal, 12)
                .frame(minWidth: 44, minHeight: 36)
                .background(Theme.accentSoft, in: Capsule())
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Order \(t.name)")
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
    }

    private func order(_ t: SampleWorkup.Test) {
        ordered.append(t.id)
        if ordered.count == SampleWorkup.testsNeeded { onFinished() }
        Task {
            if !reduceMotion { try? await Task.sleep(for: TIMING.result) }
            withAnimation(Springs.card) { _ = resulted.insert(t.id) }
        }
    }
}
