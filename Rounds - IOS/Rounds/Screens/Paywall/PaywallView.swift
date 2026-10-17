import SwiftUI

/* ─────────────────────────────────────────────────────────
 * ANIMATION STORYBOARD · Paywall
 *
 *    0ms   heart trace draws in (900ms)
 *  250ms   headline rises, y 12 → 0
 *  450ms   timeline card rises
 *  600ms   plans rise
 *
 * Choosing a plan: the ring and timeline change on one spring.
 * Reduce Motion: everything shows at once.
 * ───────────────────────────────────────────────────────── */

private enum TIMING {
    static let trace = 0.9
    static let headline = 0.25
    static let timeline = 0.45
    static let plans = 0.60
}

private enum STAGE {
    static let headline = 1, timeline = 2, plans = 3
}

/// Our own paywall, bought through StoreKit. Shown after onboarding, and whenever a signed-in
/// student has no active plan. There's no way past it without subscribing: Rounds has no free tier.
struct PaywallView: View {
    let model: PaywallModel
    @AppStorage(StudyGoal.storageKey) private var goal: StudyGoal?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @State private var stage = 0
    @State private var traced = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let plan = model.selected { timeline(plan).rise(stage >= STAGE.timeline, reduceMotion) }
                    plans.rise(stage >= STAGE.plans, reduceMotion)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            footer
        }
        .background(Theme.bg.ignoresSafeArea())
        .task { await play() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            ECGShape(beats: 1)
                .trim(from: 0, to: traced ? 1 : 0)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .frame(width: 120, height: 28)
                .accessibilityHidden(true)
            Text(PaywallPricing.headline(for: goal))
                .font(.system(size: 30, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .rise(stage >= STAGE.headline, reduceMotion)
        }
    }

    private func timeline(_ plan: SubscriptionPlan) -> some View {
        let steps = PaywallPricing.steps(plan)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.when) { i, step in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        StepDot(kind: step.kind)
                        if i < steps.count - 1 {
                            Rectangle().fill(Theme.accentSoft).frame(width: 3).frame(minHeight: 18)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.when).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                        Text(step.what).font(.system(size: 14)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 14)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .animation(Springs.card, value: plan.id)
    }

    private var plans: some View {
        VStack(spacing: 8) {
            if model.plans.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            }
            ForEach(model.plans) { plan in
                PlanRow(plan: plan, saving: plan.id == model.bestValueID ? PaywallPricing.saving(plan, in: model.plans) : nil,
                        selected: plan.id == model.selectedID) {
                    withAnimation(Springs.card) { model.selectedID = plan.id }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                Task { await model.buy() }
            } label: {
                if model.isWorking { ProgressView().tint(.white) } else { Text(model.selected.map(PaywallPricing.buttonTitle) ?? "Continue") }
            }
            .buttonStyle(PrimaryButtonStyle(height: 56))
            .disabled(model.selected == nil || model.isWorking)

            if let plan = model.selected {
                Text(PaywallPricing.finePrint(plan))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 18) {
                Button("Restore") { Task { await model.restore() } }
                Button("Terms") { if let url = AppLinks.terms { openURL(url) } }
                Button("Privacy") { if let url = AppLinks.privacyPolicy { openURL(url) } }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.accentText)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func play() async {
        if reduceMotion {
            traced = true
            stage = STAGE.plans
            return
        }
        withAnimation(.easeOut(duration: TIMING.trace)) { traced = true }
        var elapsed = 0.0
        for (mark, value) in [(TIMING.headline, STAGE.headline), (TIMING.timeline, STAGE.timeline), (TIMING.plans, STAGE.plans)] {
            try? await Task.sleep(for: .seconds(mark - elapsed))
            elapsed = mark
            withAnimation(Springs.slide) { stage = value }
        }
    }
}

/// The timeline's marker for one step: filled for today, soft for the reminder, grey after.
private struct StepDot: View {
    let kind: TrialStep.Kind

    var body: some View {
        let (glyph, fill, ink): (IconGlyph, Color, Color) = switch kind {
        case .access: (.check, Theme.accent, .white)
        case .reminder: (.bell, Theme.accentSoft, Theme.accentText)
        case .billing: (.calendarCheck, Theme.track, Theme.dim)
        case .renewal: (.clock, Theme.track, Theme.dim)
        }
        AppIcon(glyph, size: 14)
            .foregroundStyle(ink)
            .frame(width: 30, height: 30)
            .background(fill, in: Circle())
    }
}

/// One plan: radio, name with the saving badge, billing line, and the per-week price.
private struct PlanRow: View {
    let plan: SubscriptionPlan
    let saving: Int?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(selected ? Theme.accent : Theme.faint, lineWidth: 2)
                    .overlay(Circle().fill(selected ? Theme.accent : .clear).padding(6))
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(plan.period.name).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                        if let saving {
                            Text("SAVE \(saving)%")
                                .font(.system(size: 11, weight: .heavy))
                                .tracking(0.4)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Theme.accentText, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    Text(PaywallPricing.detail(plan)).font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                Text(PaywallPricing.perWeekLabel(plan)).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 62)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(selected ? Theme.accent : Theme.border, lineWidth: 2))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private extension View {
    /// Fades and lifts in when `shown` turns true; Reduce Motion fades only.
    func rise(_ shown: Bool, _ reduceMotion: Bool) -> some View {
        opacity(shown ? 1 : 0).offset(y: shown || reduceMotion ? 0 : 12)
    }
}
