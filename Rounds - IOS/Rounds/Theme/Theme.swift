import SwiftUI

// ─────────────────────────────────────────────────────────
// Rounds tokens — lifted from the "Rounds App Design" canvas
// ─────────────────────────────────────────────────────────

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

extension Color {
    /// One token, two appearances. Resolves from the environment's color scheme,
    /// so `.environment(\.colorScheme, .dark)` forces the dark value on a subtree.
    static func adaptive(dark: UInt32, light: UInt32, darkOpacity: CGFloat = 1, lightOpacity: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .light
                ? UIColor(hex: light, alpha: lightOpacity)
                : UIColor(hex: dark, alpha: darkOpacity)
        })
    }
}

/// Dark: true black, cool neutrals, electric-blue accent, vivid status colours.
/// Light: cool near-white, rich emerald accent, true-red alerts.
/// Every value was computed in OKLCH at its hue's maximum vividness, then set to the lightness that
/// passes its role: rich mid-lightness fills (not the lightest passing shade, which reads pastel);
/// white button labels APCA Lc ≥ 64, small text WCAG ≥ 4.5:1.
enum Theme {
    static let bg         = Color.adaptive(dark: 0x000000, light: 0xF5F6FB)
    static let surface    = Color.adaptive(dark: 0x131417, light: 0xFFFFFF)
    static let nav        = Color.adaptive(dark: 0x0A0B0E, light: 0xFBFCFF)
    static let text       = Color.adaptive(dark: 0xEDEEF3, light: 0x161929)
    static let muted      = Color.adaptive(dark: 0xB0B2BA, light: 0x6C6F7C)
    static let dim        = Color.adaptive(dark: 0xC2C4CB, light: 0x434755)
    static let faint      = Color.adaptive(dark: 0x76787E, light: 0x9B9EA8)
    static let accent     = Color.adaptive(dark: 0x226DFF, light: 0x029957)
    static let accentInk  = Color.adaptive(dark: 0xFFFFFF, light: 0xFFFFFF)
    static let accentText = Color.adaptive(dark: 0xA5BFEC, light: 0x028B4F)
    static let accentSoft = Color.adaptive(dark: 0x226DFF, light: 0x029957, darkOpacity: 0.12, lightOpacity: 0.10)
    static let warn       = Color.adaptive(dark: 0xFC968B, light: 0xE5011A)
    static let warnText   = Color.adaptive(dark: 0xFC968B, light: 0xE5011A)
    static let warnSoft   = Color.adaptive(dark: 0xFC968B, light: 0xE5011A, darkOpacity: 0.12, lightOpacity: 0.10)
    /// Fill for the "random patient" action: sky blue that carries a white icon in both modes.
    static let shuffle    = Color.adaptive(dark: 0x0482C0, light: 0x0482C0)
    static let info       = Color.adaptive(dark: 0x66D4FC, light: 0x0482C0)
    static let good       = Color.adaptive(dark: 0x2EE78B, light: 0x028B4F)
    /// Flashcard verdicts: true green / true red in both modes.
    static let correct    = Color.adaptive(dark: 0x04A35E, light: 0x029957)
    static let wrong      = Color.adaptive(dark: 0xE5011A, light: 0xE5011A)
    static let goodSoft   = Color.adaptive(dark: 0x2EE78B, light: 0x028B4F, darkOpacity: 0.12, lightOpacity: 0.10)
    static let bubbleMe   = Color.adaptive(dark: 0x21283D, light: 0xDDF6E5)
    static let hairline   = Color.adaptive(dark: 0xEDEEF3, light: 0x161929, darkOpacity: 0.07, lightOpacity: 0.08)
    static let ring       = Color.adaptive(dark: 0xEDEEF3, light: 0x161929, darkOpacity: 0.08, lightOpacity: 0.07)
    static let border     = Color.adaptive(dark: 0xEDEEF3, light: 0x161929, darkOpacity: 0.16, lightOpacity: 0.16)
    static let track      = Color.adaptive(dark: 0xEDEEF3, light: 0x161929, darkOpacity: 0.07, lightOpacity: 0.06)
    /// Segmented-control thumb: lifts off the track in both modes.
    static let thumb      = Color.adaptive(dark: 0x2C2C2F, light: 0xFFFFFF)
    /// Streak flame, Later button, LATER stamp: true red (no orange in the app).
    static let streak     = Color.adaptive(dark: 0xE5011A, light: 0xE5011A)
    static let streakSoft = Color.adaptive(dark: 0xE5011A, light: 0xE5011A, darkOpacity: 0.12, lightOpacity: 0.10)
    /// Badge cards read as physical trading cards: dark stock and rarity inks, the same in both
    /// modes. Every rarity ink clears 4.5:1 on the card stock (lowest: common, about 5.6:1).
    static let cardStock       = Color.adaptive(dark: 0x14161E, light: 0x14161E)
    static let cardBack        = Color.adaptive(dark: 0x10131C, light: 0x10131C)
    static let cardInk         = Color.adaptive(dark: 0xD3D5DB, light: 0xD3D5DB)
    static let rarityCommon    = Color.adaptive(dark: 0x8A93A6, light: 0x8A93A6)
    static let rarityRare      = Color.adaptive(dark: 0x4B8BFF, light: 0x4B8BFF)
    static let rarityEpic      = Color.adaptive(dark: 0xA585FF, light: 0xA585FF)
    static let rarityLegendary = Color.adaptive(dark: 0xE8C547, light: 0xE8C547)

    /// Home backdrop glows: soft colour fields behind the deck (and behind the glass buttons).
    static let glowA = Color.adaptive(dark: 0x0C59E9, light: 0x5CE295)
    static let glowB = Color.adaptive(dark: 0x7619E3, light: 0x82BEF1)
    static let glowC = Color.adaptive(dark: 0x2A9D6B, light: 0xB09CEA)

    /// ECG paper grid (light mode only): the classic pink chart-paper lines.
    static let ecgGridMinor = Color(hex: 0xE58E8E, opacity: 0.22)
    static let ecgGridMajor = Color(hex: 0xE58E8E, opacity: 0.5)

    /// Monitor glow in dark mode; nothing in light mode, where colored glow on white reads as smudge.
    static func glow(_ color: Color, _ opacity: Double) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .light
                ? .clear
                : UIColor(color).resolvedColor(with: traits).withAlphaComponent(opacity)
        })
    }

    /// Monitor sweep highlight (Sign in mark).
    static let sweep      = Color.adaptive(dark: 0xE1E5EB, light: 0x01B568)
}

extension Font {
    /// Stand-in for JetBrains Mono used on the canvas: SF Mono via the system monospaced design.
    static func mono(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Font {
    /// Big scores: proportional SF with tabular digits, avoids the mono comma gap ("1, 482").
    static func score(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold).monospacedDigit()
    }
}

enum Springs {
    static let card   = Animation.spring(response: 0.45, dampingFraction: 0.85)  // smooth settle
    static let pop    = Animation.spring(response: 0.3, dampingFraction: 0.65)   // badges, chips
    static let slide  = Animation.spring(response: 0.4, dampingFraction: 0.8)    // entrances
}
