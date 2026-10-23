import SwiftUI

/// The AI consent and Terms of Use, full screen, for a signed-in student who hasn't agreed on this
/// phone (a new account, or one that agreed to an older version). The app opens only after
/// "I agree"; signing out is the other way off this screen.
struct AIConsentView: View {
    @Environment(AuthModel.self) private var auth
    @AppStorage(AIConsent.storageKey) private var consentStored = AIConsent.withdrawn

    var body: some View {
        VStack(spacing: 0) {
            OnboardingQuestion(title: "Before you start", glyph: .shieldCheck) {
                AIConsentPoints(points: AIConsent.points, note: AIConsent.termsNote,
                                terms: AppLinks.terms, privacyPolicy: AppLinks.privacyPolicy)
            }
            VStack(spacing: 4) {
                Button("I agree") { consentStored = AIConsent.agreed }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Sign out") { Task { await auth.signOut() } }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accentText)
                    .frame(minHeight: 44)
                    .disabled(auth.busy != nil)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .problemAlert(Binding(get: { auth.problem }, set: { auth.problem = $0 }))
    }
}
