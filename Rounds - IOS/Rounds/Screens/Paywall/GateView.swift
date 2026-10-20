import SuperwallKit
import StoreKit
import SwiftUI

/// What a signed-in student without a plan sees: Superwall's paywall for the gate placement, full
/// screen. If it can't show (no key, offline, or no campaign matches), a plain fallback offers to
/// try again or restore, so nobody is stuck on a blank screen. Either way the student can sign out
/// or delete the account from here, without buying a plan first.
struct GateView: View {
    let model: PaywallModel
    @Environment(AuthModel.self) private var auth
    /// Bumped by "Try again" to rebuild Superwall's view, which loads once per instance.
    @State private var attempt = 0
    @State private var confirmDelete = false
    @State private var managingSubscription = false

    var body: some View {
        Group {
            // The phone pays, but for another account: explain rather than offer a plan Apple won't sell twice.
            if let owner = model.takenBy {
                SubscriptionTaken(owner: owner, isWorking: model.isWorking,
                                  movePlan: { Task { await model.movePlanHere() } },
                                  manage: { managingSubscription = true },
                                  signOut: { Task { await auth.signOut() } })
                    .overlay(alignment: .topLeading) { accountMenu }
            } else if SuperwallService.isConfigured, !Self.debugForcesFallback {
                PaywallView(
                    placement: SuperwallService.gatePlacement,
                    onRequestDismiss: { _, result in closed(result) },
                    onSkippedView: { reason in fallback(Self.why(reason)) },
                    onErrorView: { error in fallback(Self.why(error)) }
                )
                .id(attempt)
                .ignoresSafeArea()
                .overlay(alignment: .topLeading) { accountMenu }
            } else {
                fallback(Self.debugOnly("Superwall isn't configured: SUPERWALL_API_KEY is missing from Secrets.xcconfig."))
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .problemAlert(Binding(get: { model.problem }, set: { model.problem = $0 }))
        // Same deletion as Settings: the account and its data, for good.
        .confirmationDialog(AccountDeletion.title, isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(AccountDeletion.confirm, role: .destructive) { Task { await auth.deleteAccount() } }
            // Apple's own sheet: the only place a subscription can be cancelled.
            Button(AccountDeletion.manage) { managingSubscription = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(AccountDeletion.message)
        }
        .manageSubscriptionsSheet(isPresented: $managingSubscription)
        .background { Color.clear.problemAlert(Binding(get: { auth.problem }, set: { auth.problem = $0 })) }
        #if DEBUG
        .onAppear { if DebugLaunch.screen == "paywall-delete" { confirmDelete = true } }
        #endif
    }

    /// Top-left over the paywall: sign out or delete the account without buying.
    private var accountMenu: some View {
        AccountMenuButton(signOut: { Task { await auth.signOut() } },
                          deleteAccount: { confirmDelete = true },
                          disabled: auth.busy != nil)
            .padding(.leading, 12)
    }

    private func fallback(_ detail: String?) -> some View {
        PaywallUnavailable(
            isWorking: model.isWorking,
            detail: detail,
            retry: { attempt += 1; Task { await model.refresh() } },
            restore: { Task { await model.restore() } },
            signOut: { Task { await auth.signOut() } },
            deleteAccount: { confirmDelete = true })
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

    /// `-screen paywall-unavailable` shows the fallback even when Superwall is set up.
    private static var debugForcesFallback: Bool {
        #if DEBUG
        DebugLaunch.isPaywallUnavailable
        #else
        false
        #endif
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
        case .purchased: Task { await model.purchased() }
        case .restored: Task { await model.refresh() }
        case .declined: attempt += 1
        }
    }
}
