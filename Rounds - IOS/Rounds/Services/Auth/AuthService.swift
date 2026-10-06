import Foundation
import Supabase

/// A signed-in Rounds account (not an anonymous guest session).
struct Account: Equatable, Sendable {
    let id: String
    let email: String?
    let name: String?
    /// "email", "apple" or "google".
    let provider: String
    let createdAt: Date
    /// Finished onboarding (the promise). Kept on the account, not the device, so every way of
    /// signing in (code, Apple, Google, a new phone) routes the same way.
    var onboarded = false

    /// Up to two initials for the avatar; "?" without a name or email.
    var initials: String {
        let source = name ?? email ?? ""
        let words = source.split(whereSeparator: { $0 == " " || $0 == "@" || $0 == "." }).prefix(2)
        let letters = words.compactMap(\.first).map { String($0).uppercased() }.joined()
        return letters.isEmpty ? "?" : letters
    }

    var providerLabel: String {
        switch provider {
        case "apple": "Apple"
        case "google": "Google"
        default: "Email"
        }
    }
}

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
    /// Finishes sign-in from an email link (older emails carried one); nil when the link isn't ours.
    func handle(url: URL) async throws -> Account?
    func signOut() async throws
    /// Deletes the account and all its data on the server, then signs out.
    func deleteAccount() async throws
    /// Asks the server to send the one-time welcome email (it skips anyone already welcomed).
    func sendWelcome() async throws
    /// Records on the account that onboarding is done.
    func markOnboarded() async throws
}

/// An account action failed for a reason the student can act on; the message is shown as is.
struct AuthServiceError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// The redirect email links come back to (the app's `rounds` URL scheme).
let authRedirectURL = URL(string: "rounds://auth-callback")

struct LiveAuthService: AuthService {
    let client: SupabaseClient

    func currentAccount() async -> Account? {
        guard let user = try? await client.auth.session.user, !user.isAnonymous else { return nil }
        return Self.account(user)
    }

    func sendCode(email: String, name: String?) async throws {
        do {
            try await client.auth.signInWithOTP(email: email, redirectTo: authRedirectURL, shouldCreateUser: name != nil,
                                                data: name.map { ["full_name": .string($0)] })
        } catch let error as AuthError where [.otpDisabled, .signupDisabled].contains(error.errorCode) {
            // Log in only asks for existing accounts; the server refuses to make one.
            throw AuthServiceError(message: "There's no Rounds account for that email. Create one instead.")
        } catch let error as AuthError where error.errorCode == .overEmailSendRateLimit {
            // One code per address per minute: a code from moments ago is still in the inbox.
            // "...you can only request this after 41 seconds." → wait 41s; no number → a full minute.
            let wait = error.message.split(separator: " ").compactMap { Int($0) }.first
            throw CodeRecentlySent(wait: TimeInterval(wait ?? Int(EmailCode.resendAfter)))
        }
    }

    func verifyCode(email: String, code: String) async throws -> Account {
        do {
            return Self.account(try await client.auth.verifyOTP(email: email, token: code, type: .email).user)
        } catch let error as AuthError where error.errorCode == .otpExpired {
            throw CodeRejected()
        }
    }

    func signInWithApple(idToken: String, nonce: String, name: String?) async throws -> Account {
        let account = try await signInOrLink(OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce))
        // Apple shares the name only on the very first sign-in; keep it.
        if let name, !name.isEmpty, account.name == nil {
            _ = try? await client.auth.update(user: UserAttributes(data: ["full_name": .string(name)]))
            return Account(id: account.id, email: account.email, name: name, provider: account.provider,
                           createdAt: account.createdAt, onboarded: account.onboarded)
        }
        return account
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws -> Account {
        try await signInOrLink(OpenIDConnectCredentials(provider: .google, idToken: idToken, accessToken: accessToken))
    }

    func handle(url: URL) async throws -> Account? {
        guard url.scheme == authRedirectURL?.scheme else { return nil }
        return Self.account(try await client.auth.session(from: url).user)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func deleteAccount() async throws {
        do {
            _ = try await client.functions.invoke("delete-account") as DeleteReply
        } catch let FunctionsError.httpError(_, data) {
            let message = (try? JSONDecoder().decode(ErrorReply.self, from: data))?.error ?? "Your account couldn't be deleted."
            throw AuthServiceError(message: message.prefix(1).uppercased() + message.dropFirst())
        }
        // The server session is gone with the user; clear this device's copy.
        try? await client.auth.signOut(scope: .local)
    }

    func sendWelcome() async throws {
        _ = try await client.functions.invoke("send-welcome") as WelcomeReply
    }

    func markOnboarded() async throws {
        _ = try await client.auth.update(user: UserAttributes(data: ["onboarded": .bool(true)]))
    }

    /// A guest (anonymous) session links the new identity, so the student's patients and cards
    /// carry over; anyone else signs in normally. An identity that already belongs to another
    /// account can't be linked: then it's a plain sign-in to that account.
    private func signInOrLink(_ credentials: OpenIDConnectCredentials) async throws -> Account {
        if let current = try? await client.auth.session.user, current.isAnonymous {
            do {
                return Self.account(try await client.auth.linkIdentityWithIdToken(credentials: credentials).user)
            } catch let error as AuthError where error.errorCode == .identityAlreadyExists {
                // Falls through to signing in to the account that owns this identity.
            }
        }
        return Self.account(try await client.auth.signInWithIdToken(credentials: credentials).user)
    }

    private static func account(_ user: User) -> Account {
        let metadata = user.userMetadata
        let name = metadata["full_name"]?.stringValue ?? metadata["name"]?.stringValue
        let provider = user.appMetadata["provider"]?.stringValue ?? "email"
        return Account(id: user.id.uuidString, email: user.email, name: name, provider: provider, createdAt: user.createdAt,
                       onboarded: metadata["onboarded"]?.boolValue ?? false)
    }
}

/// The emailed code was wrong or expired: the code screen shows this inline, not as an alert.
struct CodeRejected: Error {}

/// A code went to this address moments ago, so the server won't send another yet. Not a failure
/// for the student: the code in their inbox still works, so they go on to enter it.
struct CodeRecentlySent: Error {
    /// Seconds until another code may be sent.
    let wait: TimeInterval
}

private struct DeleteReply: Decodable { let deleted: Bool }
private struct WelcomeReply: Decodable { let sent: Bool }
private struct ErrorReply: Decodable { let error: String }
