import SwiftUI

/// "Before your first shift": training level picks the first patient's difficulty.
/// Per the canvas note, this screen masks first-patient generation (3–6 s) — no spinner.
struct OnboardingView: View {
    @AppStorage("signedIn") private var signedIn = false
    @Environment(AuthRouter.self) private var router
    @State private var pick: String? = nil   // no default: the first patient depends on this answer

    private struct Level: Identifiable {
        let id: String
        let label: String
        let detail: String
    }

    private let levels = [
        Level(id: "ms12", label: "Pre-clinical (MS1–MS2)", detail: "History-taking fundamentals"),
        Level(id: "ms3", label: "Clerkships (MS3)", detail: "Common presentations, clear red flags"),
        Level(id: "ms4", label: "Final year (MS4)", detail: "Messier histories, more differentials"),
        Level(id: "img", label: "International grad", detail: "PLAB 2, NAC or USMLE-style cases"),
        Level(id: "res", label: "Resident", detail: "Atypical presentations, tight timers"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            IconButton(glyph: .chevronLeft, label: "Back to sign up") { router.back() }
                .padding(.leading, -17)   // chevron edge on the 24pt margin

            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Before your first shift")
                Text("Where are you in training?")
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-0.5)
                    .lineSpacing(-2)
                Text("Your first patient is matched to this.")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.top, 4)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(levels) { level in option(level) }
                }
                .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)

            Button("Continue") { signedIn = true }
                .disabled(pick == nil)
                .buttonStyle(PrimaryButtonStyle(height: 52))
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .background(Theme.bg.ignoresSafeArea())
    }

    private func option(_ level: Level) -> some View {
        let on = pick == level.id
        return Button {
            withAnimation(Springs.pop) { pick = level.id }
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
            .background(on ? Theme.accent.opacity(0.10) : Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(on ? Theme.accent : Theme.text.opacity(0.10), lineWidth: on ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressDownStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
