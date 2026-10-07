import SwiftUI

/// "What are you studying for?": the exams as floating bubbles; one tap picks.
struct StudyGoalView: View {
    @Environment(AuthRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(StudyGoal.storageKey) private var stored = ""
    @State private var shown = false

    /// Where each bubble floats on the 350×400 hero board.
    private static let spots: [StudyGoal: CGPoint] = [
        .step1: CGPoint(x: 30, y: 40), .step2CK: CGPoint(x: 150, y: 118), .shelf: CGPoint(x: 20, y: 200),
        .osce: CGPoint(x: 196, y: 270), .practicing: CGPoint(x: 52, y: 336),
    ]

    private var goal: StudyGoal? { StudyGoal(stored: stored) }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingTopBar(total: OnboardingStep.total, current: OnboardingStep.studyGoal) { router.back() }
                .padding(.horizontal, 20)

            VStack(spacing: 14) {
                HeroCanvas {
                    Ellipse().stroke(Theme.accent.opacity(0.14)).frame(width: 310, height: 200).at(16, 110)
                    Sparkle().fill(Theme.sparkleMint).frame(width: 26, height: 44).at(296, 30)
                    Sparkle().fill(Theme.sparkleBlue).frame(width: 20, height: 20).at(16, 372)
                }
                .overlay { bubbles }
                .frame(maxHeight: 420)
                OnboardingHeadline(text: "What Are You\nStudying For?")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer(minLength: 0)
            OnboardingNextButton(enabled: goal != nil) { router.go(.focus) }
                .padding(.bottom, 12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { shown = true }
    }

    /// The choices sit on the same scaled board as the art, but stay tappable and readable.
    private var bubbles: some View {
        GeometryReader { geo in
            let scale = HeroBoard.scale(in: geo.size)
            let origin = HeroBoard.origin(in: geo.size)
            ForEach(Array(StudyGoal.allCases.enumerated()), id: \.element) { i, g in
                let spot = Self.spots[g] ?? .zero
                bubble(g)
                    .offset(x: origin.x + spot.x * scale, y: origin.y + spot.y * scale)
                    .heroPop(shown, delay: Double(i) * 0.06)
            }
        }
    }

    private func bubble(_ g: StudyGoal) -> some View {
        let on = goal == g
        return Button {
            withAnimation(reduceMotion ? nil : Springs.pop) { stored = g.rawValue }
        } label: {
            HStack(spacing: 10) {
                if on {
                    AppIcon(.check, size: 14)
                        .foregroundStyle(Theme.accent)
                        .frame(width: 26, height: 26)
                        .background(Theme.surface, in: Circle())
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                }
                Text(g.label).font(.system(size: 19, weight: .semibold))
            }
            .foregroundStyle(on ? Theme.accentInk : Theme.text)
            .padding(.leading, on ? 14 : 22)
            .padding(.trailing, 22)
            .frame(height: 56)
            .background(on ? Theme.accent : Theme.surface, in: Capsule())
            .shadow(color: (on ? Theme.accent : Theme.text).opacity(on ? 0.32 : 0.10), radius: on ? 16 : 11, y: on ? 14 : 8)
            .scaleEffect(on && !reduceMotion ? 1.06 : 1)
        }
        .buttonStyle(PressDownStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
