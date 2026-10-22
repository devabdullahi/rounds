import SwiftUI

/// Centered pill action with a trailing arrow.
struct OnboardingNextButton: View {
    var title = "Next"
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(PrimaryButtonStyle(height: 56))
        .disabled(!enabled)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
}
