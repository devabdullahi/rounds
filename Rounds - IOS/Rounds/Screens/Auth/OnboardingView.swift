import SwiftUI

/// "Before your first shift", step 1 of 2: training level picks the first patient's difficulty
/// and whether step 2 asks for a rotation (MS3–MS4) or a system (MS1–MS2).
struct OnboardingView: View {
    @AppStorage(TrainingLevel.storageKey) private var levelStored = ""
    @Environment(AuthRouter.self) private var router
    @State private var pick: TrainingLevel? = nil   // no default: the first patient depends on this answer

    private let levels = TrainingLevel.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            IconButton(glyph: .chevronLeft, label: "Back to sign up", quiet: true) { router.back() }
                .padding(.leading, -17)   // chevron edge on the 24pt margin

            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Before your first shift · 1 of 2")
                Text("Where are you in training?")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.5)
                    .lineSpacing(-2)
                Text("Your first patient is matched to this.")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.top, 4)

            Spacer(minLength: 24)

            // Options sit just above Continue, in thumb reach, instead of leaving a gap under the title.
            VStack(spacing: 10) {
                ForEach(levels) { level in option(level) }
            }
            .padding(.bottom, 24)

            Button("Continue") {
                guard let pick else { return }
                levelStored = pick.rawValue
                router.go(.focus)
            }
                .disabled(pick == nil)
                .buttonStyle(PrimaryButtonStyle(height: 52))
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .background(Theme.bg.ignoresSafeArea())
    }

    private func option(_ level: TrainingLevel) -> some View {
        let on = pick == level
        return Button {
            withAnimation(Springs.pop) { pick = level }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.label).font(.system(size: 17, weight: .semibold))
                    Text(level.detail).font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                Spacer()
                if on {
                    AppIcon(.circleCheck, size: 22)
                        .foregroundStyle(Theme.accent)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .modifier(SelectableSurface(on: on))
        }
        .buttonStyle(PressDownStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
