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
    static let accentText = Color.adaptive(dark: 0xA5BFEC, light: 0x017A45)   // light: 5.0:1 on bg, 4.7:1 on heroMint
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
    /// Edges that identify a control (empty code boxes, unfilled progress): 3:1 against the page.
    static let control    = Color.adaptive(dark: 0xEDEEF3, light: 0x161929, darkOpacity: 0.45, lightOpacity: 0.5)
    static let track      = Color.adaptive(dark: 0xEDEEF3, light: 0x161929, darkOpacity: 0.07, lightOpacity: 0.06)
    /// Segmented-control thumb: lifts off the track in both modes.
    static let thumb      = Color.adaptive(dark: 0x2C2C2F, light: 0xFFFFFF)
    /// Streak flame, Later button, LATER stamp: true red (no orange in the app).
    static let streak     = Color.adaptive(dark: 0xE5011A, light: 0xE5011A)
    static let streakSoft = Color.adaptive(dark: 0xE5011A, light: 0xE5011A, darkOpacity: 0.12, lightOpacity: 0.10)
    /// The streak pill at 0 days: a cold slate, white text at 5.5:1.
    static let streakCold = Color.adaptive(dark: 0x4F6B8A, light: 0x4F6B8A)
    /// The streak pill's colour for each week of a streak (days 0–6, 7–13, …), then repeating.
    /// Each carries white text at 4.8:1 or better. Indexed by `Streak.weekColorIndex`.
    static let streakWeeks: [Color] = [
        streak,                                            // red
        Color.adaptive(dark: 0xC4166F, light: 0xC4166F),   // magenta, 5.7:1
        Color.adaptive(dark: 0x7B3FE4, light: 0x7B3FE4),   // purple, 5.7:1
        Color.adaptive(dark: 0x1D5FE6, light: 0x1D5FE6),   // blue, 5.5:1
        Color.adaptive(dark: 0x0B7C86, light: 0x0B7C86),   // teal, 5.0:1
    ]
    /// The streak pill and spotlight colour: cold at zero, then a new colour every 7 days.
    static func streakTint(days: Int) -> Color {
        days == 0 ? streakCold : streakWeeks[Streak.weekColorIndex(days)]
    }
    /// Badge cards read as physical trading cards: dark stock and rarity inks, the same in both
    /// modes. Every rarity ink clears 4.5:1 on the card stock (lowest: common, about 5.6:1).
    static let cardStock       = Color.adaptive(dark: 0x14161E, light: 0x14161E)
    static let cardBack        = Color.adaptive(dark: 0x10131C, light: 0x10131C)
    static let cardInk         = Color.adaptive(dark: 0xD3D5DB, light: 0xD3D5DB)
    static let rarityCommon    = Color.adaptive(dark: 0x8A93A6, light: 0x8A93A6)
    static let rarityRare      = Color.adaptive(dark: 0x4B8BFF, light: 0x4B8BFF)
    static let rarityEpic      = Color.adaptive(dark: 0xA585FF, light: 0xA585FF)
    static let rarityLegendary = Color.adaptive(dark: 0xE8C547, light: 0xE8C547)
    /// The lower end of each rarity's card art gradient: deep enough for white artwork on top.
    static let rarityCommonDeep    = Color.adaptive(dark: 0x4E5566, light: 0x4E5566)
    static let rarityRareDeep      = Color.adaptive(dark: 0x1D5FE6, light: 0x1D5FE6)
    static let rarityEpicDeep      = Color.adaptive(dark: 0x6A33D1, light: 0x6A33D1)
    static let rarityLegendaryDeep = Color.adaptive(dark: 0x8A6A00, light: 0x8A6A00)

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

    /// Onboarding illustration, used only on signed-out screens (always light mode), so these
    /// deliberately hold one value: a mint wash behind the hero art, a blush wash behind the
    /// promise heart, and sparkle tints. Give them dark values before using them signed in.
    static let heroMint    = Color.adaptive(dark: 0xDDF3E8, light: 0xDDF3E8)
    static let heroBlush   = Color.adaptive(dark: 0xFDE7EA, light: 0xFDE7EA)
    static let sparkleBlue = Color.adaptive(dark: 0x9CC3FF, light: 0x9CC3FF)
    static let sparkleMint = Color.adaptive(dark: 0x8DDBB6, light: 0x8DDBB6)
    /// Welcome screen buttons: darker than the app accent so white text clears 4.5:1.
    static let welcomeGreen = Color.adaptive(dark: 0x027A46, light: 0x027A46)
    /// The welcome quiz's unpicked answer: a soft green wash under `welcomeGreen` text.
    static let welcomeMint  = Color.adaptive(dark: 0xE3F5EA, light: 0xE3F5EA)

    /// Flashcard colours the student picks (see `CardColor`); light values are deepened for contrast.
    static let cardTeal   = Color.adaptive(dark: 0x2DD4BF, light: 0x0F8A7E)
    static let cardBlue   = Color.adaptive(dark: 0x60A5FA, light: 0x1D5FC2)
    static let cardPurple = Color.adaptive(dark: 0xA78BFA, light: 0x6D3FD6)
    static let cardPink   = Color.adaptive(dark: 0xF472B6, light: 0xC0307A)
    static let cardRed    = Color.adaptive(dark: 0xFF5A63, light: 0xE5011A)
    static let cardYellow = Color.adaptive(dark: 0xFACC15, light: 0x9A7400)
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
