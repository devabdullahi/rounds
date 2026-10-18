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
                    onSkippedView: { reason in fallback(Self.why(reason)) },
                    onErrorView: { error in fallback(Self.why(error)) }
                )
                .id(attempt)
                .ignoresSafeArea()
            } else {
                fallback(Self.debugOnly("Superwall isn't configured: SUPERWALL_API_KEY is missing from Secrets.xcconfig."))
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .problemAlert(Binding(get: { model.problem }, set: { model.problem = $0 }))
    }

    private func fallback(_ detail: String?) -> some View {
        PaywallUnavailable(
            isWorking: model.isWorking,
            detail: detail,
            retry: { attempt += 1; Task { await model.refresh() } },
            restore: { Task { await model.restore() } })
    }

    /// Superwall's reason for not showing a paywall, in debug builds only: a student never sees it.
    private static func why(_ reason: PaywallSkippedReason) -> String? {
        switch reason {
        case .placementNotFound: debugOnly("Superwall: no campaign has the placement \"\(SuperwallService.gatePlacement)\".")
        case .noAudienceMatch: debugOnly("Superwall: the campaign's audience didn't match this user.")
        case .holdout: debugOnly("Superwall: this user is in the campaign's holdout group.")
        @unknown default: debugOnly("Superwall skipped the paywall.")
        }
    }

    private static func why(_ error: Error) -> String? {
        debugOnly("Superwall error: \(error.localizedDescription)")
    }

    private static func debugOnly(_ text: String) -> String? {
        #if DEBUG
        text
        #else
        nil
        #endif
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
