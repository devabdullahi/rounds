import SwiftUI
import Observation

/// Signed-out shell: welcome and onboarding, over real accounts (AuthModel). Accounts are Apple or
/// Google only. "Get Started" runs onboarding and makes the account inside it; logging in with an
/// account that never finished onboarding runs it too. A returning account goes straight in.
struct AuthFlowView: View {
    @Environment(AuthModel.self) private var auth
    @State private var router = AuthRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            // Everyone signed out lands on the welcome screen: log in (Apple/Google), or first time.
            FirstOpenView(
                signingInWith: auth.signingInWith,
                onFirstTime: { router.go(.onboarding) },
                onSocial: { provider in Task { await continueWith(provider) } }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AuthStep.self) { step in
                switch step {
                case .onboarding: OnboardingView().toolbar(.hidden, for: .navigationBar)
                }
            }
        }
        .environment(router)
        // A second sign-in method about to become a second account: offer the one used before.
        .alert("Use your earlier account?", isPresented: Binding(get: { auth.duplicate != nil }, set: { _ in }), presenting: auth.duplicate) { earlier in
            Button("Use my \(earlier.providerLabel) account") { auth.choose(.useEarlier) }
            Button("Keep this new account", role: .cancel) { auth.choose(.keepNew) }
        } message: { earlier in
            Text("You\u{2019}ve used Rounds with \(earlier.providerLabel)\(earlier.maskedEmail.map { " (\($0))" } ?? "") on this iPhone. Sign in with \(earlier.providerLabel) once more and this sign-in will open that account, with your patients, cards and plan.")
        }
        .alert("Couldn't sign in", isPresented: Binding(get: { auth.problem != nil }, set: { if !$0 { auth.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(auth.problem ?? "")
        }
        #if DEBUG
        .onAppear {
            router.path = DebugLaunch.authPath
            if DebugLaunch.screen == "duplicate-account" { auth.debugOfferDuplicate() }
            // -screen google-signin: opens Google's sheet without a tap, to check the client ID setup.
            if DebugLaunch.screen == "google-signin" {
                Task { try? await Task.sleep(for: .seconds(1.5)); await continueWith(.google) }   // after the push settles
            }
        }
        #endif
    }

    private func continueWith(_ provider: SocialProvider) async {
        guard let account = await auth.continueWith(provider) else { return }
        router.enter(account, auth: auth)
    }
}
