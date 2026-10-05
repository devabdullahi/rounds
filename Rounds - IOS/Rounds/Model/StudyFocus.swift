import Foundation

/// What the student wants to practice. US schools each run their own curriculum, so cases
/// are tagged by topics every school shares: the core clerkships (each with an NBME shelf
/// exam) and the USMLE organ systems. Anyone can pick any mix of both; training year
/// plays no part.

enum Clerkship: String, CaseIterable, Identifiable {
    case internalMedicine, surgery, pediatrics, obgyn, psychiatry, familyMedicine, neurology, emergency
    var id: String { rawValue }

    var label: String {
        switch self {
        case .internalMedicine: "Internal medicine"
        case .surgery: "Surgery"
        case .pediatrics: "Pediatrics"
        case .obgyn: "OB/GYN"
        case .psychiatry: "Psychiatry"
        case .familyMedicine: "Family medicine"
        case .neurology: "Neurology"
        case .emergency: "Emergency medicine"
        }
    }

    var examples: String {
        switch self {
        case .internalMedicine: "Chest pain, dyspnea, sepsis"
        case .surgery: "Abdominal pain, post-op fever"
        case .pediatrics: "Febrile infant, wheeze, rash"
        case .obgyn: "Bleeding in pregnancy, pelvic pain"
        case .psychiatry: "Low mood, psychosis, withdrawal"
        case .familyMedicine: "Cough, back pain, check-ups"
        case .neurology: "Headache, weakness, seizures"
        case .emergency: "Undifferentiated, time-critical"
        }
    }
}

enum OrganSystem: String, CaseIterable, Identifiable {
    case cardiovascular, respiratory, gastrointestinal, renal, nervous, endocrine, blood, musculoskeletal, reproductive, behavioral
    var id: String { rawValue }

    var label: String {
        switch self {
        case .cardiovascular: "Cardiovascular"
        case .respiratory: "Respiratory"
        case .gastrointestinal: "Gastrointestinal"
        case .renal: "Renal & urinary"
        case .nervous: "Nervous system"
        case .endocrine: "Endocrine"
        case .blood: "Blood & immune"
        case .musculoskeletal: "MSK & skin"
        case .reproductive: "Reproductive"
        case .behavioral: "Behavioral health"
        }
    }

    var examples: String {
        switch self {
        case .cardiovascular: "Chest pain, syncope"
        case .respiratory: "Cough, wheeze"
        case .gastrointestinal: "Abdominal pain, jaundice"
        case .renal: "Dysuria, swelling"
        case .nervous: "Headache, weakness"
        case .endocrine: "Thirst, weight change"
        case .blood: "Bruising, fever"
        case .musculoskeletal: "Joint pain, rashes"
        case .reproductive: "Pelvic pain, bleeding"
        case .behavioral: "Low mood, sleep"
        }
    }
}

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

/// Everything the student picked. Students on combined blocks (say medicine and neurology,
/// or a cardio-respiratory block) can choose several; none means a mix of everything.
/// Stored comma-separated in the same @AppStorage key, so an older single value still reads.
struct FocusSelection: Equatable {
    private(set) var items: [StudyFocus] = []

    init(_ items: [StudyFocus] = []) {
        for item in items where item != .mix && !self.items.contains(item) { self.items.append(item) }
    }

    init(stored: String) {
        self.init(stored.split(separator: ",").map { StudyFocus(stored: String($0)) })
    }

    var stored: String { items.map(\.stored).joined(separator: ",") }
    var isMix: Bool { items.isEmpty }
    var leadsWithSystem: Bool { items.first?.isSystem ?? false }

    /// "Mixed cases", "Surgery", "Surgery + Neurology", or "Internal medicine +2".
    var label: String {
        switch items.count {
        case 0: return "Mixed cases"
        case 1: return items[0].label
        case 2 where items[0].label.count + items[1].label.count <= 20:
            return "\(items[0].label) + \(items[1].label)"
        default: return "\(items[0].label) +\(items.count - 1)"
        }
    }

    func contains(_ focus: StudyFocus) -> Bool { items.contains(focus) }

    mutating func toggle(_ focus: StudyFocus) {
        guard focus != .mix else { items.removeAll(); return }
        if let i = items.firstIndex(of: focus) { items.remove(at: i) } else { items.append(focus) }
    }

    /// A case fits when any picked focus fits. A mix fits everything.
    func matches(rotation: Clerkship, system: OrganSystem) -> Bool {
        isMix || items.contains { $0.matches(rotation: rotation, system: system) }
    }
}
