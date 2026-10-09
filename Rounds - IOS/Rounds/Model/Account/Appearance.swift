import Foundation

/// Settings › Appearance. Raw values are what's already stored under `storageKey`, so they must not change.
enum Appearance: Int, CaseIterable, Sendable {
    case system = 0, light = 1, dark = 2

    static let storageKey = "appearance"

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
