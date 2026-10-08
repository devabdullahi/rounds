import SwiftUI

/// Filled green check in a circle.
struct CheckDot: View {
    var size: CGFloat = 24
    var body: some View {
        AppIcon(.check, size: size * 0.55)
            .foregroundStyle(Theme.accentInk)
            .frame(width: size, height: size)
            .background(Theme.accent, in: Circle())
    }
}
