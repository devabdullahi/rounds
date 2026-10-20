import SwiftUI

/// "How Rounds uses AI": the one-time consent, just before the account is made. Onboarding's
/// "I agree" button records it; the carousel can't pass this page until then.
struct AIConsentPage: View {
    var shown = true

    var body: some View {
        OnboardingQuestion(title: "How Rounds uses AI", glyph: .shieldCheck, shown: shown) {
            AIConsentPoints(points: AIConsent.points, privacyPolicy: AppLinks.privacyPolicy)
                .modifier(QuestionEntrance(order: 1))
        }
    }
}
