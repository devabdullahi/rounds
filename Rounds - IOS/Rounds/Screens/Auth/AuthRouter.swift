import SwiftUI
import Observation

@MainActor
@Observable
final class AuthRouter {
    var path: [AuthStep] = []
    func go(_ step: AuthStep) { path.append(step) }
    func back() { if !path.isEmpty { path.removeLast() } }

    /// After any sign-in (code, Apple, Google): onboarding until the account has made its promise,
    /// then the app. One rule for every path, decided by the account, not the screen it came from.
    func enter(_ account: Account, auth: AuthModel) {
        if account.onboarded { auth.finishSignIn() } else { go(.onboarding) }
    }
}
