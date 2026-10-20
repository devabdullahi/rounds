import SwiftUI

/// The layout every onboarding question shares: the question at the top, left-aligned, an optional
/// short note under it, then the answers.
struct OnboardingQuestion<Answers: View>: View {
    let title: String
    var note: String?
    @ViewBuilder let answers: () -> Answers

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let note {
                    Text(note)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 8)
                }
                VStack(spacing: 10) { answers() }
                    .padding(.top, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }
}
