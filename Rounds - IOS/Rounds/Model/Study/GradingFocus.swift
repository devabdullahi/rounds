import Foundation

/// What the student told onboarding that shapes how a case is graded and taught: their exam (the
/// debrief adds a lens for it) and what they find hardest (feedback on those areas is marked and
/// comes first). Sent with each submission; the server decides what it changes.
struct GradingFocus: Equatable, Sendable {
    var goal: StudyGoal?
    var struggles: Set<StudyStruggle> = []

    /// The picks as onboarding stored them on this phone.
    static func stored(in defaults: UserDefaults = .standard) -> GradingFocus {
        GradingFocus(goal: StudyGoal(stored: defaults.string(forKey: StudyGoal.storageKey) ?? ""),
                     struggles: StudyStruggle.decode(defaults.string(forKey: StudyStruggle.storageKey) ?? ""))
    }

    /// The struggles in a stable order, as the server takes them.
    var struggleValues: [String] { StudyStruggle.allCases.filter(struggles.contains).map(\.rawValue) }
}
