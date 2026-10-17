import SuperwallKit
import SwiftUI

/// What a signed-in student without a plan sees: Superwall's paywall for the gate placement, full
/// screen. If it can't show (no key, offline, or no campaign matches), a plain fallback offers to
/// try again or restore, so nobody is stuck on a blank screen.
struct GateView: View {
    let model: PaywallModel
    /// Bumped by "Try again" to rebuild Superwall's view, which loads once per instance.
    @State private var attempt = 0

    var body: some View {
        Group {
            if SuperwallService.isConfigured {
                PaywallView(
                    placement: SuperwallService.gatePlacement,
                    onRequestDismiss: { _, result in closed(result) },
                    onSkippedView: { _ in fallback },
                    onErrorView: { _ in fallback }
                )
                .id(attempt)
                .ignoresSafeArea()
            } else {
                fallback
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .problemAlert(Binding(get: { model.problem }, set: { model.problem = $0 }))
    }

    private var fallback: some View {
        PaywallUnavailable(
            isWorking: model.isWorking,
            retry: { attempt += 1; Task { await model.refresh() } },
            restore: { Task { await model.restore() } })
    }

    /// The paywall closed: open the app on a purchase, re-check on a restore, show it again on a decline.
    private func closed(_ result: PaywallResult) {
        switch result {
        case .purchased(let product): Task { await model.purchased(PurchasedPlan(product)) }
        case .restored: Task { await model.refresh() }
        case .declined: attempt += 1
        }
    }
}
