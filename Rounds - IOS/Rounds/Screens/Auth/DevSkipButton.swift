#if DEBUG
import SwiftUI

/// Dev shortcut past auth. Compiled out of release builds.
struct DevSkipButton: View {
    @AppStorage(AuthModel.signedInKey) private var signedIn = false

    var body: some View {
        Button {
            signedIn = true
        } label: {
            HStack(spacing: 4) {
                Text("Skip")
                AppIcon(.chevronRight, size: 16)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.muted)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Theme.track, in: Capsule())
        }
        .buttonStyle(PressDownStyle())
        .accessibilityLabel("Skip sign in")
    }
}

extension View {
    /// Pins the dev Skip button to the top-right corner.
    func devSkip() -> some View {
        overlay(alignment: .topTrailing) {
            DevSkipButton().padding(.trailing, 16).padding(.top, 4)
        }
    }
}
#endif
