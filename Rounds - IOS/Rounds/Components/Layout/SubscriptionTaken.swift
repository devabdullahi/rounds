import SwiftUI

/// Shown instead of the paywall when this phone's subscription is in use by another Rounds account.
/// Apple sells one subscription per Apple ID, so this account can't buy again here. The student can
/// move the plan to this account (the other loses it), manage or cancel it in Apple's settings, or
/// sign in with the account that has it.
struct SubscriptionTaken: View {
    /// The account that has it, masked ("j•••@gmail.com").
    let owner: String
    let isWorking: Bool
    let movePlan: () -> Void
    let manage: () -> Void
    let signOut: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            AppIcon(.crown, size: 40)
                .foregroundStyle(Theme.accent)
            Text("This plan is on another account")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            Text("The subscription on this iPhone is being used by \(owner). Move it to this account to use it here; \(owner) will lose access.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Move plan to this account", action: movePlan)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isWorking)
            HStack(spacing: 24) {
                Button("Manage subscription", action: manage)
                Button("Use the other account", action: signOut)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.accentText)
            .frame(minHeight: 44)
            .disabled(isWorking)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}
