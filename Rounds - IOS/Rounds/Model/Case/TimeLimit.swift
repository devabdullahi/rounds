import Foundation

/// The case clock the student picks on the door note and sets a default for in Settings.
/// Both screens share the stored value, so they always show the same choice.
enum TimeLimit {
    static let storageKey = "timeLimitMinutes"
    /// Minutes; 0 means untimed.
    static let defaultMinutes = 10
    static let options: [(Int, String)] = [(5, "5 min"), (10, "10"), (15, "15"), (20, "20"), (0, "Off")]

    /// The stored choice as a session limit: nil when untimed.
    static func minutes(_ stored: Int) -> Int? { stored == 0 ? nil : stored }
}
