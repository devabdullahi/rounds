import SwiftUI

/// The onboarding doctors' fixed colors. Onboarding is always light, so these don't adapt; they
/// live here so the figures still read their colors from `Theme`.
extension Theme {
    enum Figure {
        static let coat = Color(hex: 0xFFFFFF)
        static let coatLine = Color(hex: 0x161929, opacity: 0.2)
        static let scrubs = Color(hex: 0x2F7FC8)
        static let stethoscope = Color(hex: 0x3A3D4C)
        static let bellFace = Color(hex: 0xC9CBD4)
        static let eyeWhite = Color(hex: 0xFFFFFF)
        static let ink = Color(hex: 0x14161E)
    }
}
