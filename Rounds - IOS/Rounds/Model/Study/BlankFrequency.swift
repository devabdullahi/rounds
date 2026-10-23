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
        case .often: "You're not alone."
        case .sometimes: "Pressure does that."
        case .rarely: "Nice. Let's keep it that way."
        }
    }

    var replyLine: String {
        switch self {
        case .often: "Knowing it and saying it are different skills. Rounds trains the second one."
        case .sometimes: "The more cases you talk through, the less it happens."
        case .rarely: "Recall stays sharp when you use it."
        }
    }

    /// Reads the stored raw value; nil when nothing (or something unknown) was saved.
    init?(stored: String) { self.init(rawValue: stored) }
}
