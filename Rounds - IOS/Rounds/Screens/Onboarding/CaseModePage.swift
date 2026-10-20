import SwiftUI

/// "How should cases start?": practice or exam mode by default. The same switch as Settings.
struct CaseModePage: View {
    @AppStorage(Preferences.examByDefaultKey) private var exam = Preferences.examByDefaultDefault

    var body: some View {
        OnboardingQuestion(title: "How should cases start?") {
            ChoiceRow(title: "Practice", detail: "Hints as you go, only useful tests shown", glyph: .bookOpen, on: !exam) { exam = false }
            ChoiceRow(title: "Exam", detail: "No hints, extra tests to tempt you", glyph: .clipboardList, on: exam) { exam = true }
            Text("Each case lets you switch before you start.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        }
    }
}
