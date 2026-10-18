import SwiftUI

/// Shown instead of the paywall when this phone's subscription belongs to another Rounds account:
/// a subscription unlocks only the account that bought it. Apple allows one subscription per Apple
/// ID, so this account can't buy again here; it signs in with the owner or uses another Apple ID.
struct SubscriptionTaken: View {
    /// The owning account, masked ("j•••@gmail.com").
    let owner: String
    let isWorking: Bool
    let signOut: () -> Void
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            AppIcon(.crown, size: 40)
                .foregroundStyle(Theme.accent)
            Text("This plan belongs to another account")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            Text("The subscription on this iPhone was bought by \(owner). Sign in with that account to use it, or subscribe with a different Apple ID.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Sign in with another account", action: signOut)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isWorking)
            Button("Check again", action: retry)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .frame(minHeight: 44)
                .disabled(isWorking)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}
