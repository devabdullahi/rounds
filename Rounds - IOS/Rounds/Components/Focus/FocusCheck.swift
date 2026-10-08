import SwiftUI

struct FocusCheck: View {
    let size: CGFloat
    var body: some View {
        AppIcon(.circleCheck, size: size)
            .foregroundStyle(Theme.accent)
            .transition(.scale(scale: 0.5).combined(with: .opacity))
    }
}
