import SwiftUI

/// Centered pill action with a trailing arrow.
struct OnboardingNextButton: View {
    var title = "Next"
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                AppIcon(.arrowRight, size: 18)
            }
        }
        .buttonStyle(PrimaryButtonStyle(height: 60))
        .frame(width: 230)
        .disabled(!enabled)
        .frame(maxWidth: .infinity)
    }
}
