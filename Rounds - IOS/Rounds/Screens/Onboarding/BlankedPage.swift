import SwiftUI

/// "Ever blanked on something you knew?": three answers everyone can place themselves in. The
/// answer only picks the encouraging screen after it (BlankedReplyPage).
struct BlankedPage: View {
    var shown = true
    @AppStorage(BlankFrequency.storageKey) private var stored = ""

    private static let glyphs: [BlankFrequency: IconGlyph] = [.often: .messageSquare, .sometimes: .activity, .rarely: .target]

    var body: some View {
        OnboardingQuestion(title: "Ever blanked on something you knew?", shown: shown) {
            ForEach(Array(BlankFrequency.allCases.enumerated()), id: \.element) { i, answer in
                ChoiceRow(title: answer.label, detail: answer.detail, glyph: Self.glyphs[answer],
                          on: stored == answer.rawValue, order: i) { stored = answer.rawValue }
            }
        }
    }
}
