import SwiftUI

/// Big centered headline under the hero.
struct OnboardingHeadline: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 32, weight: .bold))
            .tracking(-0.6)
            .multilineTextAlignment(.center)
            .lineSpacing(-2)
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilitySortPriority(1)   // read before the art and choices above it
    }
}
