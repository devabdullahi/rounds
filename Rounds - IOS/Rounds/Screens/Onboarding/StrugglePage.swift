import SwiftUI

/// "What feels hardest?": any number of picks.
struct StrugglePage: View {
    var shown = true
    @AppStorage(StudyStruggle.storageKey) private var stored = ""

    private static let glyphs: [StudyStruggle: IconGlyph] = [
        .whatToAsk: .messageSquare, .differential: .compass, .tests: .flask, .timing: .timer, .talking: .user,
    ]

    var body: some View {
        let picks = StudyStruggle.decode(stored)
        OnboardingQuestion(title: "What feels hardest?", glyph: .lightning, note: "Pick any.", shown: shown) {
            ForEach(Array(StudyStruggle.allCases.enumerated()), id: \.element) { i, struggle in
                ChoiceRow(title: struggle.label, glyph: Self.glyphs[struggle], tint: ChoiceRow.tint(i),
                          on: picks.contains(struggle), multiple: true, order: i) {
                    var next = picks
                    if next.contains(struggle) { next.remove(struggle) } else { next.insert(struggle) }
                    stored = StudyStruggle.encode(next)
                }
            }
        }
    }
}
