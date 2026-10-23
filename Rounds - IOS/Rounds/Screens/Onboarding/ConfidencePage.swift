import SwiftUI

/// "How sure are you of your diagnoses?": 1 to 10, one tap. The reality check after it
/// reads the number back.
struct ConfidencePage: View {
    var shown = true
    @AppStorage(DiagnosisConfidence.storageKey) private var stored = 0


    var body: some View {
        OnboardingQuestion(title: "How sure are you of your diagnoses?", shown: shown) {
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
                Text("1 · Not sure")
                Spacer()
                Text("10 · Very sure")
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)
            .padding(.top, 8)

        }
        .sensoryFeedback(.selection, trigger: stored)
    }
}
