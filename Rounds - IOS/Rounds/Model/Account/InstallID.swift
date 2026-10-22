import Foundation

/// A random id for this install, made on first use and kept in UserDefaults. It tells one install's
/// onboarding steps apart before there's an account; it's never the device's own identifier, and a
/// reinstall gets a new one.
enum InstallID {
    static let storageKey = "installID"

    static func current(in defaults: UserDefaults = .standard) -> UUID {
        if let stored = defaults.string(forKey: storageKey).flatMap(UUID.init(uuidString:)) { return stored }
        let made = UUID()
        defaults.set(made.uuidString, forKey: storageKey)
        return made
    }
}
