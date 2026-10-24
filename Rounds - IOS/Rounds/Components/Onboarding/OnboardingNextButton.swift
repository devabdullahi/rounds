import SwiftUI

/// The onboarding pages' main button: a full-width pill. Disabled, its label turns muted grey so it
/// stays readable on the faint fill instead of white on near-white.
struct OnboardingNextButton: View {
    var title = "Continue"
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).foregroundStyle(enabled ? Theme.accentInk : Theme.muted)
        }
        .buttonStyle(PrimaryButtonStyle(height: 56))
        .disabled(!enabled)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
}
