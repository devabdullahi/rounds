import SwiftUI

/// "How sure are you diagnosing a patient today?": 1 to 10, one tap. A one-line card then reads
/// back how long is left and their own number.
struct ConfidencePage: View {
    var shown = true
    @AppStorage(DiagnosisConfidence.storageKey) private var stored = 0
    @AppStorage(ExamMonth.storageKey) private var examStored = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var confidence: DiagnosisConfidence? { DiagnosisConfidence(stored: stored) }
    private var exam: ExamMonth? { ExamMonth(stored: examStored) }

    var body: some View {
        OnboardingQuestion(title: "How sure are you diagnosing a patient today?", shown: shown) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(Array(DiagnosisConfidence.range), id: \.self) { n in
                    Button { stored = n } label: {
                        Text("\(n)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.text)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .modifier(SelectableSurface(on: stored == n))
                    }
                    .buttonStyle(PressDownStyle())
                    .accessibilityLabel("\(n) out of 10")
                    .accessibilityAddTraits(stored == n ? .isSelected : [])
                    .modifier(QuestionEntrance(order: (n - 1) / 5))
                }
            }
            HStack {
                Text("Not at all")
                Spacer()
                Text("Very sure")
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)
            .padding(.top, 8)

            if let confidence {
                card(confidence)
                    .padding(.top, 20)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: stored)
        .sensoryFeedback(.selection, trigger: stored)
    }

    /// One line, readable at a glance: how long is left, and their own number.
    private func card(_ confidence: DiagnosisConfidence) -> some View {
        Text(exam.map { "\($0.weeksLeft()) weeks left. You're a \(confidence.value)." } ?? "You're a \(confidence.value). Let's raise it.")
            .font(.system(size: 21, weight: .bold))
            .foregroundStyle(Theme.accentInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Theme.welcomeGreen, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
