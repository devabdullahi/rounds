import SwiftUI

/// Secondary action: same glass and white text, slightly smaller type by default.
struct SoftButtonStyle: ButtonStyle {
    var height: CGFloat = 54
    var fontSize: CGFloat = 17
    var tint: Color = Theme.accentFill
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(.white)
            .glassFill(tint, in: RoundedRectangle(cornerRadius: height / 2, style: .continuous), strength: SOFT.strength)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Springs.pop, value: configuration.isPressed)
    }
}

private enum SOFT {
    /// Full colour, like the primary: iOS 26's glass already lifts the fill, and any page showing
    /// through on top drops white text under 4.5:1 (0.95 measured 4.3–4.7:1 across the label).
    static let strength = 1.0
}
