import SwiftUI

/// Shown in place of the paywall when it can't load: what happened, two ways forward, and the
/// ways out (sign out, delete the account), so nobody is stuck here without a plan.
struct PaywallUnavailable: View {
    let isWorking: Bool
    /// Why it couldn't load, shown small under the message (debug builds pass Superwall's reason).
    var detail: String? = nil
    let retry: () -> Void
    let restore: () -> Void
    let signOut: () -> Void
    /// Asks to delete the account; the caller confirms first.
    let deleteAccount: () -> Void

    var body: some View {
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
            if let detail {
                Text(detail)
                    .font(.mono(13))
                    .foregroundStyle(Theme.warnText)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
            Spacer()
            Button("Try again", action: retry)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isWorking)
            Button("Restore purchases", action: restore)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .frame(minHeight: 44)
                .disabled(isWorking)
            HStack(spacing: 24) {
                Button("Sign out", action: signOut)
                    .foregroundStyle(Theme.muted)
                Button("Delete account", role: .destructive, action: deleteAccount)
                    .foregroundStyle(Theme.warnText)
            }
            .font(.system(size: 15, weight: .semibold))
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}
