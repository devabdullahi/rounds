import SwiftUI

/// "How do you want to talk to patients?": out loud or typing. Sets the voice mode switch that
/// Settings also shows.
struct TalkStylePage: View {
    @AppStorage(Preferences.voiceModeKey) private var voice = Preferences.voiceModeDefault

    var body: some View {
        OnboardingQuestion(title: "How do you want to talk to patients?") {
            ChoiceRow(title: "Out loud", detail: "Speak, and the patient answers back", glyph: .mic, on: voice) { voice = true }
            ChoiceRow(title: "Typing", detail: "Quiet, good for the library", glyph: .messageSquare, on: !voice) { voice = false }
            Text("You can switch any time during a case.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        }
    }
}
