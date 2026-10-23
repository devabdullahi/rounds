import Foundation

/// The onboarding value pages' headlines, said back to the student with what they've answered so
/// far: their exam, their focus, their name. Each falls back to the general line until its answer
/// exists, and keeps to two short lines. Pure, so the wording rules are tested.
struct OnboardingHeadlines: Equatable {
    var goal: StudyGoal?
    var focus: FocusSelection?
    /// The name as typed; only the first word is used ("Sam", not "Sam Lee").
    var name: String?

    /// Longest focus label that still fits "Learn From Every … Miss" on two lines.
    private static let focusFits = 18

    private var firstName: String? {
        name.flatMap(ProfileName.clean).flatMap { $0.split(separator: " ").first.map(String.init) }
    }

    var examReady: String {
        switch goal {
        case .step1: "Walk Into Step 1\nReady"
        case .step2CK: "Walk Into Step 2 CK\nReady"
        case .shelf: "Walk Into Your\nShelves Ready"
        case .osce: "Walk Into Your\nOSCEs Ready"
        case .other, .practicing, nil: "Walk Into Your\nExam Ready"
        }
    }

    var promise: String {
        firstName.map { "Think Like a\nDoctor, \($0)" } ?? "Think Like\na Doctor"
    }

    var missCards: String {
        guard let focus, !focus.isMix, focus.items.count == 1, focus.label.count <= Self.focusFits else {
            return "Learn From\nEvery Miss"
        }
        return "Learn From Every\n\(focus.label) Miss"
    }

    var progress: String {
        firstName.map { "\($0), See Where\nYou're Improving" } ?? "See Where You're\nGetting Better"
    }
}
