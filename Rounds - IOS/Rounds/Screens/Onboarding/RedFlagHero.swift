import SwiftUI

/// "Spot the red flag": a chest-pain patient and four things they say. Tapping one answers: the red
/// flag turns green with a check; a wrong pick turns red and shakes, and the right one lights up.
struct RedFlagHero: View {
    let shown: Bool
    /// The option picked so far; set once, so the answer can't be changed after seeing it.
    @Binding var picked: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shakes = 0

    private let quiz = RedFlagQuiz.chestPain

    var body: some View {
        HeroCanvas {
            Sparkle().fill(Theme.sparkleMint).frame(width: 26, height: 44).at(316, 4).heroPop(shown, delay: 0.3)
            Sparkle().fill(Theme.sparkleBlue).frame(width: 20, height: 20).at(6, 380).heroPop(shown, delay: 0.34)
        }
        .overlay {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    PatientAvatar(initials: "RM", size: 44, tint: .blue)
                    Text(quiz.patient).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                    Spacer(minLength: 0)
                }
                .heroPop(shown, delay: 0)
                ForEach(Array(quiz.options.enumerated()), id: \.element.id) { i, option in
                    row(option).heroPop(shown, delay: 0.06 + Double(i) * 0.06)
                }
            }
            .frame(width: 330)
        }
    }

    private func row(_ option: RedFlagQuiz.Option) -> some View {
        let answered = picked != nil
        let chosen = picked == option.id
        let right = answered && option.isRedFlag
        let wrong = chosen && !option.isRedFlag
        return Button {
            guard picked == nil else { return }
            withAnimation(reduceMotion ? nil : Springs.pop) { picked = option.id }
            if !option.isRedFlag && !reduceMotion { withAnimation(.linear(duration: 0.4)) { shakes += 1 } }
        } label: {
            HStack(spacing: 10) {
                Text(option.text)
                    .font(.system(size: 15, weight: .medium))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if right { AppIcon(.check, size: 16).transition(.scale.combined(with: .opacity)) }
                if wrong { AppIcon(.x, size: 16).transition(.scale.combined(with: .opacity)) }
            }
            .foregroundStyle(right ? Theme.accentInk : wrong ? Theme.warnText : Theme.text)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(right ? Theme.accent : wrong ? Theme.warnSoft : Theme.surface,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Theme.text.opacity(0.08), radius: 10, y: 6)
            .opacity(answered && !right && !chosen ? 0.55 : 1)
            .modifier(Shake(amount: wrong ? 8 : 0, shakes: CGFloat(shakes)))
        }
        .buttonStyle(PressDownStyle())
        .disabled(answered && !chosen && !right)
        .accessibilityValue(right ? "Red flag" : wrong ? "Not the red flag" : "")
    }
}

/// A side-to-side wobble, three times per shake.
private struct Shake: GeometryEffect {
    var amount: CGFloat
    var shakes: CGFloat
    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(shakes * .pi * 6), y: 0))
    }
}
