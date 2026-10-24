import SwiftUI

/// Secondary action beside a primary one (Retry next to Next patient): the same Liquid Glass and
/// white text, on a slate fill instead of the accent, and only as wide as its label, so the main
/// action still leads.
struct QuietButtonStyle: ButtonStyle {
    var height: CGFloat = 54
    var fontSize: CGFloat = 16
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(minHeight: height)
            .glassFill(Theme.neutralFill, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Springs.pop, value: configuration.isPressed)
    }
}
