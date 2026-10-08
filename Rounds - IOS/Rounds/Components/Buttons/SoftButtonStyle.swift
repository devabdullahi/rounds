import SwiftUI

/// Secondary action: same glass and white text, slightly smaller type by default.
struct SoftButtonStyle: ButtonStyle {
    var height: CGFloat = 54
    var fontSize: CGFloat = 17
    var tint: Color = Theme.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(.white)
            .glassFill(tint, in: RoundedRectangle(cornerRadius: height / 2, style: .continuous), strength: 0.75)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Springs.pop, value: configuration.isPressed)
    }
}
