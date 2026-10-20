import SwiftUI

/// "How do you want to talk to patients?": out loud or typing. Sets the voice mode switch that
/// Settings also shows.
struct TalkStylePage: View {
    var shown = true
    @AppStorage(Preferences.voiceModeKey) private var voice = Preferences.voiceModeDefault

    var body: some View {
        OnboardingQuestion(title: "How do you want to talk to patients?", glyph: .audioLines, shown: shown) {
            ChoiceRow(title: "Out loud", detail: "Speak, and the patient answers back", glyph: .mic, tint: ChoiceRow.tint(0), on: voice) { voice = true }
            ChoiceRow(title: "Typing", detail: "Quiet, good for the library", glyph: .messageSquare, tint: ChoiceRow.tint(1), on: !voice, order: 1) { voice = false }
            Text("You can switch any time during a case.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
                .modifier(QuestionEntrance(order: 2))
        }
    }
}
