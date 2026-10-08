import SwiftUI

/// Fictional patients' avatar tints in the onboarding art: pastel fill with a deep ink of the
/// same hue (initials clear 7:1 on every fill). Signed-out only, like the hero tokens above.
enum AvatarTint: CaseIterable {
    case blue, pink, yellow, purple, mint, rose

    var fill: Color {
        switch self {
        case .blue: Color.adaptive(dark: 0xCFE4FF, light: 0xCFE4FF)
        case .pink: Color.adaptive(dark: 0xF5D5EC, light: 0xF5D5EC)
        case .yellow: Color.adaptive(dark: 0xFFF0B8, light: 0xFFF0B8)
        case .purple: Color.adaptive(dark: 0xD9D2FF, light: 0xD9D2FF)
        case .mint: Color.adaptive(dark: 0xCFF3E2, light: 0xCFF3E2)
        case .rose: Color.adaptive(dark: 0xFFD6DA, light: 0xFFD6DA)
        }
    }

    var ink: Color {
        switch self {
        case .blue: Color.adaptive(dark: 0x1C3F7A, light: 0x1C3F7A)
        case .pink: Color.adaptive(dark: 0x6A2457, light: 0x6A2457)
        case .yellow: Color.adaptive(dark: 0x5C4A00, light: 0x5C4A00)
        case .purple: Color.adaptive(dark: 0x35277A, light: 0x35277A)
        case .mint: Color.adaptive(dark: 0x0B4F31, light: 0x0B4F31)
        case .rose: Color.adaptive(dark: 0x7A1320, light: 0x7A1320)
        }
    }
}
