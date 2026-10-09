import SwiftUI

/// "Before your first shift": what to practice. A page of the onboarding carousel, after the
/// study goal; the promise follows. Topics, not training year: anyone can pick rotations, systems,
/// or both (the tabs only switch the list; picks on both tabs are kept), or mix it up.
struct FocusPage: View {
    @Environment(AppState.self) private var app
    @Binding var pick: FocusSelection
    /// "Mix it up" is an answer too; nothing tapped yet is not.
    @Binding var mixChosen: Bool
    @State private var bySystem = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Before your first shift")
                Text("What do you want to practice?")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.5)
                    .lineSpacing(-2)
                Text(pick.isMix ? "Pick one or more. Matching patients come first." : "\(pick.items.count) picked · matching patients come first.")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.muted)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: pick.items.count)
            }
            .padding(.top, 4)

            Segmented(options: [(false, "Specialty"), (true, "System")], selection: $bySystem)
                .padding(.top, 18)

            ScrollView {
                FocusGrid(byRotation: !bySystem, counts: app.topicCounts, selection: $pick, mixChosen: $mixChosen)
                    .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 24)
        #if DEBUG
        .onAppear { if DebugLaunch.screen == "focus-system" { bySystem = true } }
        #endif
    }
}
