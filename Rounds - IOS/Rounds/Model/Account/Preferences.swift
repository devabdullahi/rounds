import Foundation

/// Settings the student toggles in Settings, stored in `UserDefaults`. Views read them with
/// `@AppStorage(Preferences.xKey)` and the matching default; models read the current value through
/// the static accessors, so the key and its default live in one place.
enum Preferences {
    /// New cases open on the door note in Exam mode instead of Practice.
    static let examByDefaultKey = "examByDefault"
    static let examByDefaultDefault = false

    /// The "Revealed: …" chips in the interview chat. Exam mode hides them regardless.
    static let showRevealsKey = "showReveals"
    static let showRevealsDefault = true

    /// The key history coverage meter at the top of the interview.
    static let showCoverageKey = "showCoverage"
    static let showCoverageDefault = true

    /// Every `.sensoryFeedback` in the app goes through `.haptic`, which checks this.
    static let hapticsKey = "haptics"
    static let hapticsDefault = true

    /// The local notification two hours before a streak ends.
    static let streakAlertsKey = "streakAlerts"
    static let streakAlertsDefault = true

    /// The mic button in the interview composer.
    static let voiceModeKey = "voiceMode"
    static let voiceModeDefault = true

    /// In voice mode, a pause sends the question; when off, the student taps the orb.
    static let autoSendKey = "voiceAutoSend"
    static let autoSendDefault = true

    /// Patient speech speed, 0 (slowest) … 1 (fastest); 0.5 is the natural rate.
    static let voiceSpeedKey = "voiceSpeed"
    static let voiceSpeedDefault = 0.5

    static var examByDefault: Bool { bool(examByDefaultKey, examByDefaultDefault) }
    static var streakAlerts: Bool { bool(streakAlertsKey, streakAlertsDefault) }
    static var autoSend: Bool { bool(autoSendKey, autoSendDefault) }
    static var voiceSpeed: Double {
        UserDefaults.standard.object(forKey: voiceSpeedKey) as? Double ?? voiceSpeedDefault
    }

    /// `UserDefaults.bool` reads a missing key as false, which would flip the defaults that are on.
    private static func bool(_ key: String, _ fallback: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? fallback
    }
}
