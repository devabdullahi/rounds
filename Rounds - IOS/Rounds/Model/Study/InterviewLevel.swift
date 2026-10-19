import Foundation

/// How comfortable the student is taking a history, asked once during onboarding. Stored for
/// tuning how much a patient volunteers later; nothing reads it yet.
enum InterviewLevel: String, CaseIterable, Identifiable {
    case justStarting, gettingThere, confident

    static let storageKey = "interviewLevel"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .justStarting: "Just starting"
        case .gettingThere: "Getting there"
        case .confident: "Confident"
        }
    }

    /// Lit bars in the level's signal glyph, 1…3.
    var bars: Int {
        switch self {
        case .justStarting: 1
        case .gettingThere: 2
        case .confident: 3
        }
    }

    /// Reads the stored raw value; nil when nothing (or something unknown) was saved.
    init?(stored: String) { self.init(rawValue: stored) }
}
