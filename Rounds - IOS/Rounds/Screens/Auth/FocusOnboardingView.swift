import SwiftUI

/// "Before your first shift", step 2 of 2: what the student is studying right now.
/// MS3–MS4 pick a rotation; MS1–MS2 pick a system. Schools order both differently,
/// so the year alone can't say which patients to put first.
struct FocusOnboardingView: View {
    @AppStorage("signedIn") private var signedIn = false
    @AppStorage(TrainingLevel.storageKey) private var levelStored = ""
    @AppStorage(StudyFocus.storageKey) private var focusStored = ""
    @Environment(AuthRouter.self) private var router
    @State private var pick = FocusSelection()
    @State private var mixChosen = false   // "mix it up" is an answer too; nothing tapped yet is not

    private var byRotation: Bool { (TrainingLevel(rawValue: levelStored) ?? .ms3).studiesByRotation }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            IconButton(glyph: .chevronLeft, label: "Back to training year", quiet: true) { router.back() }
                .padding(.leading, -17)   // chevron edge on the 24pt margin

            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Before your first shift · 2 of 2")
                Text(byRotation ? "Which rotation are you on?" : "Which block are you in?")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.5)
                    .lineSpacing(-2)
                Text(byRotation ? "Pick one or more. Matching patients come first." : "Pick one or more systems. We'll match patients to them.")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.top, 4)

            ScrollView {
                FocusGrid(byRotation: byRotation, selection: $pick, mixChosen: $mixChosen)
                    .padding(.vertical, 20)
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
        .onAppear { if DebugLaunch.screen?.hasPrefix("focus-") == true { pick = FocusSelection(byRotation ? [.rotation(.internalMedicine), .rotation(.neurology)] : [.system(.cardiovascular)]) } }
        #endif
    }
}
