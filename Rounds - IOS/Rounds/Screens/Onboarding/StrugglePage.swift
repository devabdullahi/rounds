import SwiftUI

/// "What feels hardest?": any number of picks.
struct StrugglePage: View {
    @AppStorage(StudyStruggle.storageKey) private var stored = ""

    var body: some View {
        let picks = StudyStruggle.decode(stored)
        OnboardingQuestion(title: "What feels hardest?", note: "Pick any.") {
            ForEach(StudyStruggle.allCases) { struggle in
                ChoiceRow(title: struggle.label, on: picks.contains(struggle), multiple: true) {
                    var next = picks
                    if next.contains(struggle) { next.remove(struggle) } else { next.insert(struggle) }
                    stored = StudyStruggle.encode(next)
                }
            }
        }
    }
}
