import SwiftUI

/// Under the sign-in buttons: making an account is the student's agreement, to the Terms of Use and
/// Privacy Policy (both linked) and to what they type and say going to our AI providers (App Review
/// 5.1.2(i)), then the practice-only line. Signing in records it (`AIConsent.agreed`).
struct SignUpTermsNote: View {
    var body: some View {
        VStack(spacing: 4) {
            Text(agreement)
                .tint(Theme.accentText)
            Text("For practice only. Fictional patients, not medical advice.")
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.muted)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var agreement: AttributedString {
        let markdown = AIConsent.signUpNote(terms: AppLinks.terms, privacy: AppLinks.privacyPolicy)
        return (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    }
}
