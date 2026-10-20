import Foundation

/// What the student finds hardest, asked during onboarding (any number). Stored on the device for
/// now; nothing reads it yet.
enum StudyStruggle: String, CaseIterable, Identifiable {
    case whatToAsk, differential, tests, timing, talking

    static let storageKey = "studyStruggles"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .whatToAsk: "Knowing what to ask"
        case .differential: "Building a differential"
        case .tests: "Choosing the right tests"
        case .timing: "Finishing on time"
        case .talking: "Talking with patients"
        }
    }

    /// The picks as stored: raw values joined by commas, in the list's order.
    static func encode(_ picks: Set<StudyStruggle>) -> String {
        allCases.filter(picks.contains).map(\.rawValue).joined(separator: ",")
    }

    /// The stored picks; unknown values are dropped.
    static func decode(_ stored: String) -> Set<StudyStruggle> {
        Set(stored.split(separator: ",").compactMap { StudyStruggle(rawValue: String($0)) })
    }
}
