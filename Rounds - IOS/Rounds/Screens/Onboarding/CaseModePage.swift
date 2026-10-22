import SwiftUI

/// "How should cases start?": practice or exam mode by default. The same switch as Settings.
struct CaseModePage: View {
    var shown = true
    @AppStorage(Preferences.examByDefaultKey) private var exam = Preferences.examByDefaultDefault

    var body: some View {
        OnboardingQuestion(title: "How should cases start?", glyph: .clipboardList, shown: shown) {
            ChoiceRow(title: "Practice", detail: "Hints as you go, only useful tests shown", glyph: .bookOpen, tint: ChoiceRow.tint(1), on: !exam) { exam = false }
            ChoiceRow(title: "Exam", detail: "No hints, extra tests to tempt you", glyph: .shieldCheck, tint: ChoiceRow.tint(2), on: exam, order: 1) { exam = true }
            Text("Each case lets you switch before you start.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
                .modifier(QuestionEntrance(order: 2))
        }
    }
}
