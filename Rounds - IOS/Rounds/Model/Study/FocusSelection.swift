import Foundation

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
