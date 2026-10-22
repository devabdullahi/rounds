import SwiftUI

/// "Which one is the red flag?": a chest-pain patient and four things they say. One tap answers:
/// the red flag is marked right, a wrong pick is marked wrong, and a line says why.
struct RedFlagPage: View {
    var shown = true
    /// The option picked (its text); set once, so the answer can't change after it's shown.
    @Binding var picked: String?

    private let quiz = RedFlagQuiz.chestPain
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        OnboardingQuestion(title: "Which one is the red flag?", glyph: .siren, shown: shown) {
            HStack(spacing: 12) {
                PatientAvatar(initials: "RM", size: 40, tint: .blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(quiz.patient).font(.system(size: 15, weight: .semibold))
                    Text("Chest tightness since this morning").font(.system(size: 14)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.text)
            .padding(14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.text.opacity(0.08)))
            .accessibilityElement(children: .combine)
            .padding(.bottom, 4)
            .modifier(QuestionEntrance(order: 0))

            ForEach(Array(quiz.options.enumerated()), id: \.element.id) { i, option in
                row(option).modifier(QuestionEntrance(order: i + 1))
            }

            if let picked {
                let right = quiz.answer?.id == picked
                Text(right ? "Right. Jaw pain with sweating points to the heart."
                           : "Not quite. Jaw pain with sweating points to the heart.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(right ? Theme.accentText : Theme.warnText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
    }

    private func row(_ option: RedFlagQuiz.Option) -> some View {
        let answered = picked != nil
        let chosen = picked == option.id
        let right = answered && option.isRedFlag
        let wrong = chosen && !option.isRedFlag
        return Button {
            guard picked == nil else { return }
            withAnimation(reduceMotion ? nil : QUESTION.spring) { picked = option.id }
        } label: {
            HStack(spacing: 12) {
                Text(option.text)
                    .font(.system(size: 16, weight: right || wrong ? .semibold : .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if right { FocusCheck(size: 22) }
                if wrong { AppIcon(.circleX, size: 22).foregroundStyle(Theme.wrong) }
            }
            .foregroundStyle(answered && !right && !wrong ? Theme.muted : Theme.text)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(wrong ? Theme.warnSoft : right ? Theme.accent.opacity(0.10) : Theme.surface,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(wrong ? Theme.wrong : right ? Theme.accent : Theme.text.opacity(0.10),
                                  lineWidth: right || wrong ? 1.5 : 1)
            )
        }
        .buttonStyle(PressDownStyle())
        .disabled(answered)
        .haptic(option.isRedFlag ? .success : .error, trigger: chosen) { _, now in now }
        .accessibilityValue(right ? "Red flag" : wrong ? "Not the red flag" : "")
    }
}
