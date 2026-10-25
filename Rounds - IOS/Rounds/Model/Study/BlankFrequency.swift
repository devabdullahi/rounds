import Foundation

/// "Ever blanked on something you knew?", asked in onboarding. The answer only picks the
/// encouraging screen that follows; nothing in practice changes because of it.
enum BlankFrequency: String, CaseIterable, Identifiable {
    case often, sometimes, rarely

    static let storageKey = "blankFrequency"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .often: "All the time"
        case .sometimes: "Sometimes"
        case .rarely: "Rarely"
        }
    }

    var detail: String {
        switch self {
        case .often: "It's there, then it's gone"
        case .sometimes: "Usually when it counts"
        case .rarely: "Pressure doesn't get me"
        }
    }

    /// The next screen's headline and line.
    var replyHeadline: String {
        switch self {
        case .often: "You're in good company."
        case .sometimes: "Nerves are normal."
        case .rarely: "Sharp. Keep it that way."
        }
    }

    var replyLine: String {
        switch self {
        case .often: "Blanking is a recall problem, not a knowledge problem."
        case .sometimes: "Every case you talk through makes the next one calmer."
        case .rarely: "Recall fades without use. A case a day keeps it."
        }
    }

    /// Reads the stored raw value; nil when nothing (or something unknown) was saved.
    init?(stored: String) { self.init(rawValue: stored) }
}
