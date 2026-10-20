import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Tests (the workup tab's second half)
 *
 * ORDER (tap Order)
 *    0ms   tests-taken bar springs to the new count
 *    0ms   row leaves "Order more" (fades), result card enters
 *          above it, scale 0.95 → 1.0
 *
 * RESULT LANDS (as soon as the server sends it)
 *    0ms   "Pending" spinner swaps for "Resulted" (pops 0.8 → 1.0)
 *    0ms   ECG strip fades in and starts sweeping
 *    0ms   placeholder line crossfades to the result text
 *
 * Every change is a spring on current state, so ordering several
 * tests quickly stacks cards smoothly instead of queueing.
 * ───────────────────────────────────────────────────────── */

private enum RESULT {
    static let enterScale: CGFloat = 0.95      // new result card grows in from
    static let badgeScale: CGFloat = 0.8       // "Resulted" badge pops from
    static let spring = Springs.card           // card entry, reflow, result swap
    static let exit = Animation.easeOut(duration: 0.15)
}

/// Ordering tests and reading their results, inside the interview's workup tab.
struct TestsPanel: View {
    let session: CaseSession

    private var c: ClinicalCase { session.clinical }
    private var resulted: [Investigation] { session.testOrder.compactMap { id in c.tests.first { $0.id == id } } }
    private var orderable: [Investigation] { session.menuReady ? session.menu.filter { session.tests[$0.id] == nil } : [] }

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    takenCard

                    ForEach(resulted) { t in
                        resultCard(t)
                            .transition(.asymmetric(insertion: .scale(scale: RESULT.enterScale).combined(with: .opacity),
                                                    removal: .opacity.animation(RESULT.exit)))
                    }

                    if !orderable.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(resulted.isEmpty ? "Order tests" : "Order more")
                            VStack(spacing: 0) {
                                ForEach(Array(orderable.enumerated()), id: \.element.id) { i, t in
                                    if i > 0 { Hairline() }
                                    orderRow(t)
                                }
                            }
                            .listSurface()
                        }
                    }
                }
                .padding(16)
                .animation(RESULT.spring, value: session.testOrder)
        }
        .scrollIndicators(.hidden)
        .task { await session.loadMenu() }
    }

    /// How many of the menu's tests have been taken.
    private var takenCard: some View {
        let taken = session.testsTaken
        return CountProgressCard(title: "Tests taken", done: taken.done, total: taken.total,
                                 accessibilityNoun: "taken", ready: session.menuReady)
    }

    private func resultCard(_ t: Investigation) -> some View {
        let ready = session.tests[t.id] == .ready
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t.name).font(.system(size: 17, weight: .semibold))
                Spacer()
                if ready {
                    Pill(text: "Resulted", fg: Theme.dim, bg: Theme.track)
                        .transition(.scale(scale: RESULT.badgeScale).combined(with: .opacity))
                } else {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini).tint(Theme.muted)
                        Text("Pending")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                }
            }
            // MOCK (disabled): ECG strip fixed at 104 bpm with ST elevation, from the chest-pain case.
            // if t.id == "ecg" && ready { ECGMonitor(bpm: 104, stElevation: true, height: 90) … }
            let result = session.results[t.id]
            Text(ready ? (result?.text ?? "") : "Waiting on the result…")
                .font(.system(size: 15))
                .lineSpacing(3)
                .foregroundStyle(ready ? (result?.isAbnormal == true ? Theme.warnText : Theme.text) : Theme.muted)
                .contentTransition(.opacity)
        }
        .card()
        .animation(RESULT.spring, value: ready)
    }

    private func orderRow(_ t: Investigation) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(t.name).font(.system(size: 16, weight: .medium))
                if !t.kind.isEmpty { Text(t.kind).font(.system(size: 13)).foregroundStyle(Theme.muted) }
            }
            Spacer()
            // Soft like Examine: each test is a choice to weigh, not a call to action.
            Button("Order") { session.order(t) }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .padding(.horizontal, 12)
                .frame(minWidth: 44, minHeight: 36)
                .background(Theme.accentSoft, in: Capsule())
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Order \(t.name)")
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
    }
}
