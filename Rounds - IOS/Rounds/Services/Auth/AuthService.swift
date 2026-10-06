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

    /// Made moments ago: a first sign-in with Apple or Google, which still needs onboarding.
    func isNew(now: Date = .now) -> Bool { now.timeIntervalSince(createdAt) < 120 }

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

enum SignUpOutcome: Equatable, Sendable {
    case signedIn(Account)
    /// Email confirmation is on: the account exists once the student taps the link we sent.
    case confirmEmail(String)
}

/// Everything the app asks of accounts. Models depend on this; the live version is Supabase Auth.
protocol AuthService: Sendable {
    /// The signed-in account, or nil when signed out or only a guest (anonymous) session.
    func currentAccount() async -> Account?
    func signUp(email: String, password: String, name: String) async throws -> SignUpOutcome
    func signIn(email: String, password: String) async throws -> Account
    /// `nonce` is the raw value whose SHA-256 went into Apple's request.
    func signInWithApple(idToken: String, nonce: String, name: String?) async throws -> Account
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> Account
    /// Finishes sign-in from an email confirmation link; nil when the link isn't ours.
    func handle(url: URL) async throws -> Account?
    func signOut() async throws
    /// Deletes the account and all its data on the server, then signs out.
    func deleteAccount() async throws
}

/// The redirect email confirmation links come back to (the app's `rounds` URL scheme).
let authRedirectURL = URL(string: "rounds://auth-callback")

struct LiveAuthService: AuthService {
    let client: SupabaseClient

    func currentAccount() async -> Account? {
        guard let user = try? await client.auth.session.user, !user.isAnonymous else { return nil }
        return Self.account(user)
    }

    func signUp(email: String, password: String, name: String) async throws -> SignUpOutcome {
        let response = try await client.auth.signUp(email: email, password: password,
                                                     data: ["full_name": .string(name)], redirectTo: authRedirectURL)
        if let session = response.session { return .signedIn(Self.account(session.user)) }
        return .confirmEmail(email)
    }

    func signIn(email: String, password: String) async throws -> Account {
        Self.account(try await client.auth.signIn(email: email, password: password).user)
    }

    func signInWithApple(idToken: String, nonce: String, name: String?) async throws -> Account {
        let account = try await signInOrLink(OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce))
        // Apple shares the name only on the very first sign-in; keep it.
        if let name, !name.isEmpty, account.name == nil {
            _ = try? await client.auth.update(user: UserAttributes(data: ["full_name": .string(name)]))
            return Account(id: account.id, email: account.email, name: name, provider: account.provider, createdAt: account.createdAt)
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
            throw CaseServiceError(message: message.prefix(1).uppercased() + message.dropFirst())
        }
        // The server session is gone with the user; clear this device's copy.
        try? await client.auth.signOut(scope: .local)
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
        return Account(id: user.id.uuidString, email: user.email, name: name, provider: provider, createdAt: user.createdAt)
    }
}

private struct DeleteReply: Decodable { let deleted: Bool }
private struct ErrorReply: Decodable { let error: String }
