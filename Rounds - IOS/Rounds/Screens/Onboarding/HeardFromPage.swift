import SwiftUI

/// "How did you hear about Rounds?": one tap, or Skip. Kept on the phone.
struct HeardFromPage: View {
    var shown = true
    @AppStorage(HeardFrom.storageKey) private var stored = ""

    var body: some View {
        OnboardingQuestion(title: "How did you hear about Rounds?", shown: shown) {
            ForEach(Array(HeardFrom.allCases.enumerated()), id: \.element) { i, source in
                ChoiceRow(title: source.label, on: stored == source.rawValue, order: i) { stored = source.rawValue }
            }
        }
    }
}
