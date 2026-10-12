import SwiftUI

/// "Continue with Apple" and "Continue with Google", stacked: the only ways to sign in or sign up.
/// Used by the welcome screen's log-in sheet and onboarding's account page.
struct ProviderButtons: View {
    /// The provider whose sheet is open, so its row shows progress and both rows wait.
    var busy: SocialProvider?
    let onSelect: (SocialProvider) -> Void

    var body: some View {
        VStack(spacing: 12) {
            row(.apple, "Continue with Apple") {
                // Apple's mark is required on Sign in with Apple and only ships as an SF Symbol.
                Image(systemName: "apple.logo").font(.system(size: 19, weight: .medium)).offset(y: -1)
            }
            row(.google, "Continue with Google") { GoogleLogo(size: 18) }
        }
        .disabled(busy != nil)
    }

    /// Rows share one icon column on the leading edge; the label stays centered.
    private func row<Icon: View>(_ provider: SocialProvider, _ title: String, @ViewBuilder icon: () -> Icon) -> some View {
        Button { onSelect(provider) } label: {
            ZStack {
                HStack {
                    Group {
                        if busy == provider { ProgressView() } else { icon() }
                    }
                    .frame(width: 22, height: 22)
                    Spacer()
                }
                .padding(.leading, 20)
                Text(title)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.text)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.border))
            .contentShape(Capsule())
        }
        .buttonStyle(PressDownStyle())
    }
}
