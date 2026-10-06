import Foundation
import Observation

/// The sign-in providers offered next to email.
enum SocialProvider { case apple, google }

/// Accounts for the signed-out screens and Settings: who's signed in, what's in progress, and the
/// one place the app switches between the account flow and the app (`signedInKey`).
@MainActor
@Observable
final class AuthModel {
    /// The app shows its tabs when this is true (read with @AppStorage by RootView).
    static let signedInKey = "signedIn"

    enum Busy: Equatable { case email, apple, google, signOut, delete }

    private let service: (any AuthService)?
    /// Where the signed-in flag lives: standard in the app, a private store in tests.
    private let defaults: UserDefaults
    private(set) var account: Account?
    private(set) var busy: Busy?
    /// Shown as an alert by the screen that started the action.
    var problem: String?
    /// Sign-up sent a confirmation link here; the account is ready once it's tapped.
    private(set) var pendingEmail: String?

    init(service: (any AuthService)?, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
    }

    /// On launch: picks up a session the SDK kept in the keychain.
    func restore() async {
        account = await service?.currentAccount()
    }

    /// True when the student is signed in straight away (no confirmation needed).
    func signUp(email: String, password: String, name: String) async -> Bool {
        await run(.email) { service in
            switch try await service.signUp(email: email.trimmed, password: password, name: name.trimmed) {
            case .signedIn(let account):
                self.account = account
                return true
            case .confirmEmail(let address):
                self.pendingEmail = address
                return false
            }
        } ?? false
    }

    func signIn(email: String, password: String) async -> Bool {
        await run(.email) { service in
            self.account = try await service.signIn(email: email.trimmed, password: password)
            return true
        } ?? false
    }

    /// Apple's or Google's sheet, then Supabase. Nil when cancelled or failed (the failure is in
    /// `problem`). A brand-new account still needs onboarding: see `Account.isNew`.
    func continueWith(_ provider: SocialProvider) async -> Account? {
        await run(provider == .apple ? .apple : .google) { service in
            let account: Account
            switch provider {
            case .apple:
                let apple = try await AppleSignIn().signIn()
                account = try await service.signInWithApple(idToken: apple.idToken, nonce: apple.nonce, name: apple.name)
            case .google:
                let google = try await GoogleAuth.signIn()
                account = try await service.signInWithGoogle(idToken: google.idToken, accessToken: google.accessToken)
            }
            self.account = account
            return account
        }
    }

    /// A link the app was opened with: Google's sheet returning, or an email confirmation.
    /// True when it finished signing in.
    func open(_ url: URL) async -> Bool {
        if GoogleAuth.handle(url) { return false }
        let account = await run(.email) { service in try await service.handle(url: url) } ?? nil
        guard let account else { return false }
        self.account = account
        pendingEmail = nil
        finishSignIn()
        return true
    }

    /// Into the app (after onboarding, for a new account).
    func finishSignIn() {
        defaults.set(true, forKey: Self.signedInKey)
    }

    func signOut() async {
        _ = await run(.signOut) { service in try await service.signOut() }
        leave()
    }

    /// True when the account and its data are gone.
    func deleteAccount() async -> Bool {
        let done = await run(.delete) { service in try await service.deleteAccount(); return true } ?? false
        if done { leave() }
        return done
    }

    private func leave() {
        account = nil
        pendingEmail = nil
        defaults.set(false, forKey: Self.signedInKey)
    }

    /// Runs one action with its busy state; errors land in `problem`, a cancelled sheet stays quiet.
    private func run<T>(_ kind: Busy, _ action: (any AuthService) async throws -> T) async -> T? {
        guard let service, busy == nil else { return nil }
        busy = kind
        defer { busy = nil }
        do {
            return try await action(service)
        } catch is SignInCancelled {
            return nil
        } catch {
            problem = error.localizedDescription
            return nil
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
