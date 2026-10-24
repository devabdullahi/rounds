import SwiftUI

/// Main action: accent-tinted Liquid Glass pill, white text.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var height: CGFloat = 54
    var tint: Color = Theme.accentFill
    /// Off for buttons inside draggable cards: the glass must not swell when a swipe starts on it.
    var reactive = true
    func makeBody(configuration: Configuration) -> some View {
        if reactive {
            configuration.label
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: height)
                .foregroundStyle(.white)
                .glassFill(isEnabled ? tint : Theme.faint, in: RoundedRectangle(cornerRadius: height / 2, style: .continuous),
                           strength: isEnabled ? GLASS.tint : GLASS.disabled)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(Springs.pop, value: configuration.isPressed)
        } else if #available(iOS 26, *) {
            // Real Liquid Glass, but non-interactive: it doesn't swell or flare under a finger,
            // so a swipe that starts on the button leaves it as it is.
            configuration.label
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: height)
                .foregroundStyle(.white)
                .glassFill(isEnabled ? tint : Theme.faint, in: RoundedRectangle(cornerRadius: height / 2, style: .continuous),
                           strength: isEnabled ? GLASS.tint : GLASS.disabled, interactive: false)
        } else {
            // Before iOS 26, a static glass look: nothing can swell, stretch or ripple it.
            let shape = RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            configuration.label
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: height)
                .foregroundStyle(.white)
                .background(isEnabled ? tint : Theme.faint, in: shape)
                .overlay(
                    shape.fill(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.04), .clear],
                                              startPoint: .top, endPoint: .center))
                        .allowsHitTesting(false)
                )
                .overlay(shape.strokeBorder(.white.opacity(0.35), lineWidth: 1).allowsHitTesting(false))
        }
    }
}

private enum GLASS {
    static let tint = 1.0          // tint strength: the colour reads clearly, glass still shows
    static let disabled = 0.45
    static let highlight = 0.16    // how much lighter the top of each button's gradient is
}

extension View {
    /// Tinted interactive Liquid Glass in any shape; solid fill before iOS 26.
    @ViewBuilder
    func glassFill<S: Shape>(_ tint: Color, in shape: S, strength: Double = GLASS.tint, interactive: Bool = true) -> some View {
        // The colour lives in a vivid gradient *under* clear glass, so the glass adds shine and
        // depth without washing the colour out (tinted glass blends it toward grey).
        let fill = ZStack {
            shape.fill(tint.opacity(strength))
            shape.fill(LinearGradient(colors: [.white.opacity(GLASS.highlight), .clear], startPoint: .top, endPoint: .bottom))
        }
        if #available(iOS 26, *) {
            self.glassEffect(.clear.interactive(interactive), in: shape)
                .background { fill }
        } else {
            self.background { fill }
                .overlay(shape.stroke(.white.opacity(0.25), lineWidth: 1))
        }
    }

    func glassCircle(tint: Color) -> some View { glassFill(tint, in: Circle()) }
    func glassCapsule(tint: Color) -> some View { glassFill(tint, in: Capsule()) }
}

/* Every button in the app is Liquid Glass, tinted with its main colour, with white text and icons.
 * iOS 26+: interactive glass (flexes and shimmers under the finger).
 * Earlier iOS: a solid fill of the same colour, so text stays white and readable. */

/// Kept for existing call sites; identical to PrimaryButtonStyle.
typealias GlassPrimaryButtonStyle = PrimaryButtonStyle
