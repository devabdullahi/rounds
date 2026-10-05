import SwiftUI

/// "Before your first shift": the one onboarding question, what to practice.
/// Topics, not training year: anyone can pick rotations, systems, or both (the tabs only
/// switch the list; picks on both tabs are kept), or mix it up.
struct FocusOnboardingView: View {
    @AppStorage("signedIn") private var signedIn = false
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    @Environment(AuthRouter.self) private var router
    @State private var pick = FocusSelection()
    @State private var mixChosen = false   // "mix it up" is an answer too; nothing tapped yet is not
    @State private var bySystem = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            IconButton(glyph: .chevronLeft, label: "Back", quiet: true) { router.back() }
                .padding(.leading, -17)   // chevron edge on the 24pt margin

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

            Segmented(options: [(false, "Rotation"), (true, "System")], selection: $bySystem)
                .padding(.top, 18)

            ScrollView {
                FocusGrid(byRotation: !bySystem, selection: $pick, mixChosen: $mixChosen)
                    .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)

            Button("Start my shift") {
                focusStored = pick.stored
                signedIn = true
            }
            .disabled(pick.isMix && !mixChosen)
            .buttonStyle(PrimaryButtonStyle(height: 52))
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .background(Theme.bg.ignoresSafeArea())
        #if DEBUG
        .onAppear {
            if DebugLaunch.screen == "focus-system" { bySystem = true; pick = FocusSelection([.system(.cardiovascular)]) }
            else if DebugLaunch.screen == "onboarding" { pick = FocusSelection([.rotation(.internalMedicine), .rotation(.neurology)]) }
        }
        #endif
    }
}
