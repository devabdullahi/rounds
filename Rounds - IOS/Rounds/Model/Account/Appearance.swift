import Foundation

/// Settings › Appearance. Raw values are what's already stored under `storageKey`, so they must not change.
enum Appearance: Int, CaseIterable, Sendable {
    case system = 0, light = 1, dark = 2

    static let storageKey = "appearance"

    /// What a student who never picked gets: Light, whatever iOS is set to. Rounds is designed
    /// light-first (the signed-out screens and paywall are always light), so the app opens the same
    /// way. An explicit System or Dark choice is stored and kept.
    static let defaultChoice = Appearance.light

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
