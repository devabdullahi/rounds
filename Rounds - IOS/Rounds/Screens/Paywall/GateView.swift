import SwiftUI

/// What a signed-in student without a plan sees: the paywall, or, if the plans can't load, a plain
/// fallback that offers to try again or restore, so nobody is stuck on a spinner.
struct GateView: View {
    let model: PaywallModel

    var body: some View {
        Group {
            if model.plansFailed {
                PaywallUnavailable(
                    isWorking: model.isWorking,
                    retry: { Task { await model.loadPlans() } },
                    restore: { Task { await model.restore() } })
            } else {
                PaywallView(model: model)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .problemAlert(Binding(get: { model.problem }, set: { model.problem = $0 }))
    }
}
