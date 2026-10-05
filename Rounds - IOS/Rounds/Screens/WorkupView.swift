import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Workup
 *
 * ORDER (tap a price)
 *    0ms   cost bar springs to the new total
 *    0ms   row leaves "Order more" (fades), result card enters
 *          above it, scale 0.95 → 1.0
 *
 * RESULT LANDS (after the test's turnaround)
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

struct WorkupView: View {
    @Environment(CaseRouter.self) private var router
    let session: CaseSession
    @State private var pendingConfirm: Investigation?

    private var c: ClinicalCase { session.clinical }
    private var resulted: [Investigation] { session.testOrder.compactMap { id in c.tests.first { $0.id == id } } }
    private var orderable: [Investigation] { c.tests.filter { session.tests[$0.id] == nil } }

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Investigations") {
                IconButton(glyph: .chevronLeft, label: "Back to patient") { router.back() }
            } trailing: {
                CountdownLabel(session: session)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    budgetCard

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
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .animation(RESULT.spring, value: session.testOrder)
            }
            .scrollIndicators(.hidden)

            Button("I'm ready to diagnose") { router.go(.diagnosis) }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
        }
        .background(Theme.bg)
        .confirmationDialog(
            "Order \(pendingConfirm?.name ?? "")?",
            isPresented: Binding(get: { pendingConfirm != nil }, set: { if !$0 { pendingConfirm = nil } }),
            titleVisibility: .visible,
            presenting: pendingConfirm
        ) { t in
            Button("Order for $\(t.cost)", role: .destructive) { session.order(t) }
            Button("Cancel", role: .cancel) {}
        } message: { t in
            Text(consequence(of: t))
        }
    }

    /// Cheap, fast tests order on one tap. Budget-busting or care-delaying ones ask first.
    private func requestOrder(_ t: Investigation) {
        if session.spent + t.cost > c.budget || t.delaysCareMinutes > 0 {
            pendingConfirm = t
        } else {
            session.order(t)
        }
    }

    private func consequence(of t: Investigation) -> String {
        var parts: [String] = []
        let after = session.spent + t.cost
        if after > c.budget { parts.append("Takes the workup to $\(after) of a $\(c.budget) budget.") }
        if t.delaysCareMinutes > 0 { parts.append("Delays definitive treatment by \(t.delaysCareMinutes) minutes.") }
        return parts.joined(separator: " ")
    }

    private var budgetCard: some View {
        let over = session.spent > c.budget
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Workup cost").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("$\(session.spent) of $\(c.budget) budget")
                    .font(.system(size: 15))
                    .foregroundStyle(over ? Theme.warn : Theme.muted)
                    .contentTransition(.numericText())
            }
            ProgressBar(value: Double(session.spent) / Double(c.budget), color: over ? Theme.warn : Theme.accent)
        }
        .card(padding: 14)
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
            if t.id == "ecg" && ready {
                ECGMonitor(bpm: 104, stElevation: true, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .background(Theme.bg.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.ring))
            }
            Text(ready ? t.result : "Waiting on \(t.detail.lowercased())…")
                .font(.system(size: 15))
                .lineSpacing(3)
                .foregroundStyle(ready ? (t.resultIsAbnormal ? Theme.warnText : Theme.text) : Theme.muted)
                .contentTransition(.opacity)
        }
        .card()
        .animation(RESULT.spring, value: ready)
    }

    private func orderRow(_ t: Investigation) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(t.name).font(.system(size: 16, weight: .medium))
                Text(t.detail).font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            Spacer()
            // Soft like Examine: prices are choices to weigh, not calls to action.
            Button("$\(t.cost)") { requestOrder(t) }
                .font(.mono(15, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .padding(.horizontal, 12)
                .frame(minWidth: 44, minHeight: 36)
                .background(Theme.accentSoft, in: Capsule())
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Order \(t.name), \(t.cost) dollars")
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
    }
}
