import SuperwallKit
import SwiftUI

/// The plans, opened on purpose from Settings by a student who hasn't paid yet (for example while
/// using the free cases). Same Superwall placement as the gate, so the same paywall and products;
/// unlike the gate it can always be closed. App Review looks for the subscriptions here.
struct PlansSheet: View {
    let model: PaywallModel
    @Environment(\.dismiss) private var dismiss
    /// Bumped by "Try again" to rebuild Superwall's view, which loads once per instance.
    @State private var attempt = 0
    /// The paywall sold a plan; reported once the sheet is gone, so the root's welcome can present.
    @State private var bought = false

    var body: some View {
        Group {
            if SuperwallService.isConfigured {
                // Superwall draws nothing until the paywall and its products load; the spinner shows through.
                ZStack {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Theme.accent)
                        .accessibilityLabel("Loading plans")
                    PaywallView(
                        placement: SuperwallService.gatePlacement,
                        onRequestDismiss: { _, result in closed(result) },
                        // Superwall shows these in its place when it can't load the paywall.
                        onSkippedView: { _ in unavailable },
                        onErrorView: { _ in unavailable }
                    )
                    .id(attempt)
                    .ignoresSafeArea()
                }
            } else {
                unavailable
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
        // The gate's paywall may have no close button of its own; this sheet always does.
        .overlay(alignment: .topTrailing) {
            IconButton(glyph: .x, label: "Close", size: 20, quiet: true) { dismiss() }
                .padding(.trailing, 12)
        }
        .problemAlert(Binding(get: { model.problem }, set: { model.problem = $0 }))
        .onDisappear { if bought { Task { await model.purchased() } } }
    }

    private var unavailable: some View {
        VStack(spacing: 16) {
            Spacer()
            AppIcon(.crown, size: 40)
                .foregroundStyle(Theme.accent)
            Text("Plans couldn't load")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("Check your connection and try again.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Try again") { attempt += 1 }
            .buttonStyle(PrimaryButtonStyle())
            Button("Restore purchases") {
                Task {
                    await model.restore()
                    if model.isEntitled == true { dismiss() }
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.accentText)
            .frame(minHeight: 44)
            .disabled(model.isWorking)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    /// Bought: close, then the root shows the welcome. Restored: check again, then close. Declined: close.
    private func closed(_ result: PaywallResult) {
        switch result {
        case .purchased: bought = true
        case .restored: Task { await model.refresh() }
        case .declined: break
        }
        dismiss()
    }
}
