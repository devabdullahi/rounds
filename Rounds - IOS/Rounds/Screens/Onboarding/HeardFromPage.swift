import SwiftUI

/// "How did you hear about Rounds?": one tap, or Skip. Kept on the phone. Two columns, so all
/// eight answers fit above the button without a hidden scroll.
struct HeardFromPage: View {
    var shown = true
    @AppStorage(HeardFrom.storageKey) private var stored = ""

    var body: some View {
        OnboardingQuestion(title: "How did you hear about Rounds?", shown: shown) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(Array(HeardFrom.allCases.enumerated()), id: \.element) { i, source in
                    ChoiceRow(title: source.label, on: stored == source.rawValue, order: i) { stored = source.rawValue }
                }
            }
        }
    }
}
