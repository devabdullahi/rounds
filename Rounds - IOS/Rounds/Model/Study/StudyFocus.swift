import Foundation

/// What the student wants to practice. US schools each run their own curriculum, so cases
/// are tagged by topics every school shares: the core clerkships (each with an NBME shelf
/// exam) and the USMLE organ systems. Anyone can pick any mix of both; training year
/// plays no part. Clinical psychology sits with the rotations: its cases use the same screens,
/// written as a psychologist's intake (mental status exam, questionnaires). Dermatology is there
/// too: its exam is charted as a skin exam with lesion morphology (Rounds has no photos).

/// The current focus, stored as one string so it fits in @AppStorage:
/// "rotation:<Clerkship>", "system:<OrganSystem>", or "" for a mix.
enum StudyFocus: Hashable {
    case mix
    case rotation(Clerkship)
    case system(OrganSystem)

    static let storageKey = "studyFocus"

    init(stored: String) {
        let parts = stored.split(separator: ":").map(String.init)
        guard parts.count == 2 else { self = .mix; return }
        switch parts[0] {
        case "rotation": self = Clerkship(rawValue: parts[1]).map(StudyFocus.rotation) ?? .mix
        case "system": self = OrganSystem(rawValue: parts[1]).map(StudyFocus.system) ?? .mix
        default: self = .mix
        }
    }

    var stored: String {
        switch self {
        case .mix: ""
        case .rotation(let c): "rotation:\(c.rawValue)"
        case .system(let s): "system:\(s.rawValue)"
        }
    }

    var label: String {
        switch self {
        case .mix: "Mixed cases"
        case .rotation(let c): c.label
        case .system(let s): s.label
        }
    }

    var isSystem: Bool { if case .system = self { true } else { false } }

    /// Whether a case belongs in this focus. A mix matches everything.
    func matches(rotation: Clerkship, system: OrganSystem) -> Bool {
        switch self {
        case .mix: true
        case .rotation(let c): c == rotation
        case .system(let s): s == system
        }
    }
}
