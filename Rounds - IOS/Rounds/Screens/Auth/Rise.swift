import SwiftUI

/// Staggered rise used across auth screens. Never blocks taps; Reduce Motion shows everything at once.
struct Rise: ViewModifier {
    let shown: Bool
    let delay: Double
    var offset: CGFloat = 12
    var fadeOnly = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || fadeOnly ? 0 : offset)
            .animation(.timingCurve(0.2, 0.7, 0.2, 1, duration: fadeOnly ? 0.4 : 0.45).delay(delay), value: shown)
    }
}

extension View {
    func rise(_ shown: Bool, at delay: Double, offset: CGFloat = 12, fadeOnly: Bool = false) -> some View {
        modifier(Rise(shown: shown, delay: delay, offset: offset, fadeOnly: fadeOnly))
    }
}
