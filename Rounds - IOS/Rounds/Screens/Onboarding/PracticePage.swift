import SwiftUI

/// "What do you want to practice?": any rotations or body systems, or a mix, the same rows as the
/// Focus sheet. Nothing shows as picked until the student taps, and Continue waits for that.
struct PracticePage: View {
    var shown = true
    var counts: [String: Int] = [:]
    /// Called on every pick, so the page's Continue can open.
    var onPicked: () -> Void = {}
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    @State private var bySystem = false
    @State private var touched = false

    private var focus: FocusSelection { FocusSelection(stored: focusStored) }

    var body: some View {
        OnboardingQuestion(title: "What do you want to practice?", shown: shown) {
            Segmented(options: [(false, "Rotation"), (true, "Body systems")], selection: $bySystem)
                .padding(.bottom, 14)
                .modifier(QuestionEntrance(order: 0))
            FocusTopicList(focus: focus, bySystem: bySystem, counts: counts, showsSelection: touched) { value in
                // The first tap starts a fresh pick, so an old selection from a past run can't linger.
                var next = touched ? focus : FocusSelection()
                next.toggle(value)
                pick(next)
            } onMix: {
                pick(FocusSelection())
            }
            .modifier(QuestionEntrance(order: 1))
        }
    }

    private func pick(_ selection: FocusSelection) {
        withAnimation(Springs.pop) {
            touched = true
            focusStored = selection.stored
        }
        onPicked()
    }
}
