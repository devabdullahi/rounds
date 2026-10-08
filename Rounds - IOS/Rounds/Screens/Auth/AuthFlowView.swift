import SwiftUI
import Observation

/// Signed-out shell: welcome, sign up, log in and onboarding, over real accounts (AuthModel).
/// A new account goes through onboarding (intro pages, study goal, focus, promise); a returning one goes straight in.
struct AuthFlowView: View {
    @Environment(AuthModel.self) private var auth
    @State private var router = AuthRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            // Everyone signed out lands on the welcome screen; its sheet branches to
            // sign up, email log in, or Apple/Google.
            FirstOpenView(
                onSignUp: { router.go(.signUp) },
                onLogIn: { router.go(.signIn) },
                onSocial: { provider in Task { await continueWith(provider) } }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: AuthStep.self) { step in
                Group {
                    switch step {
                    case .signIn: SignInView()
                    case .signUp: SignUpView()
                    case .onboarding: OnboardingView()
                    case .code(let email): EmailCodeView(email: email)
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .environment(router)
        .alert("Couldn't sign in", isPresented: Binding(get: { auth.problem != nil }, set: { if !$0 { auth.problem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(auth.problem ?? "")
        }
        #if DEBUG
        .onAppear {
            router.path = DebugLaunch.authPath
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
