import Foundation
import Supabase

/// Everything the app asks of accounts. Models depend on this; the live version is Supabase Auth.
protocol AuthService: Sendable {
    /// The signed-in account, or nil when signed out or only a guest (anonymous) session.
    func currentAccount() async -> Account?
    /// Emails a one-time code (no passwords in Rounds). With `name`, it may create the account
    /// (sign up); without, only an existing account gets one (log in).
    func sendCode(email: String, name: String?) async throws
    /// Signs in with the emailed code.
    func verifyCode(email: String, code: String) async throws -> Account
    /// `nonce` is the raw value whose SHA-256 went into Apple's request.
    func signInWithApple(idToken: String, nonce: String, name: String?) async throws -> Account
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> Account
    /// Adds Apple as a way into the signed-in account.
    func linkApple(idToken: String, nonce: String) async throws -> Account
    /// Adds Google as a way into the signed-in account.
    func linkGoogle(idToken: String, accessToken: String) async throws -> Account
    /// Finishes sign-in from an email link (older emails carried one); nil when the link isn't ours.
    func handle(url: URL) async throws -> Account?
    func signOut() async throws
    /// Deletes the account and all its data on the server, then signs out.
    func deleteAccount() async throws
    /// Asks the server to send the one-time welcome email (it skips anyone already welcomed).
    func sendWelcome() async throws
    /// Records on the account that onboarding is done.
    func markOnboarded() async throws
    /// Saves the name the student goes by (already cleaned by `ProfileName`).
    func updateName(_ name: String) async throws -> Account
    /// Saves the specialty they're aiming for; nil clears it.
    func updateSpecialty(_ specialty: Specialty?) async throws -> Account
    /// Uses a picked image as the profile photo (shrunk to a small JPEG before upload).
    func updatePhoto(_ picked: Data) async throws -> Account
}

/// The redirect email links come back to (the app's `rounds` URL scheme).
let authRedirectURL = URL(string: "rounds://auth-callback")
