import SwiftUI

/// Shown in place of the paywall when it can't load: what happened, and two ways forward.
struct PaywallUnavailable: View {
    let isWorking: Bool
    let retry: () -> Void
    let restore: () -> Void

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
            Spacer()
            Button("Try again", action: retry)
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isWorking)
            Button("Restore purchases", action: restore)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accentText)
                .frame(minHeight: 44)
                .disabled(isWorking)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}
