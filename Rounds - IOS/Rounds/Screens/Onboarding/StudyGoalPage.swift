import SwiftUI

/// "What are you studying for?": the exams and other goals, one tap picks.
struct StudyGoalPage: View {
    var shown = true
    @AppStorage(StudyGoal.storageKey) private var stored = ""

    private static let glyphs: [StudyGoal: IconGlyph] = [
        .step1: .bookOpen, .step2CK: .stethoscope, .shelf: .clipboardList, .osce: .user, .other: .more, .practicing: .dice,
    ]

    var body: some View {
        OnboardingQuestion(title: "What are you studying for?", shown: shown) {
            ForEach(Array(StudyGoal.allCases.enumerated()), id: \.element) { i, goal in
                ChoiceRow(title: goal.label, glyph: Self.glyphs[goal], tint: ChoiceRow.tint(i),
                          on: StudyGoal(stored: stored) == goal, order: i) { stored = goal.rawValue }
            }
        }
    }
}
