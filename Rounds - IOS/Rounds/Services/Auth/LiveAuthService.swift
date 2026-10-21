import Foundation
import Supabase

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
                           createdAt: account.createdAt, avatarURL: account.avatarURL, specialty: account.specialty,
                           onboarded: account.onboarded)
        }
        return account
    }

    func signInWithGoogle(idToken: String, accessToken: String) async throws -> Account {
        try await signInOrLink(OpenIDConnectCredentials(provider: .google, idToken: idToken, accessToken: accessToken))
    }

    func linkApple(idToken: String, nonce: String) async throws -> Account {
        try await link(OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce))
    }

    func linkGoogle(idToken: String, accessToken: String) async throws -> Account {
        try await link(OpenIDConnectCredentials(provider: .google, idToken: idToken, accessToken: accessToken))
    }

    private func link(_ credentials: OpenIDConnectCredentials) async throws -> Account {
        do {
            return Self.account(try await client.auth.linkIdentityWithIdToken(credentials: credentials).user)
        } catch let error as AuthError where error.errorCode == .identityAlreadyExists {
            throw AuthServiceError(message: "That sign-in already belongs to another Rounds account. Sign in with it to use that account.")
        }
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
            _ = try await client.invokeSigned("delete-account") as DeleteReply
        } catch let FunctionsError.httpError(_, data) {
            let message = (try? JSONDecoder().decode(ErrorReply.self, from: data))?.error ?? "Your account couldn't be deleted."
            throw AuthServiceError(message: message.prefix(1).uppercased() + message.dropFirst())
        }
        // The server session is gone with the user; clear this device's copy.
        try? await client.auth.signOut(scope: .local)
    }

    func sendWelcome() async throws {
        _ = try await client.invokeSigned("send-welcome") as WelcomeReply
    }

    func markOnboarded() async throws {
        _ = try await client.auth.update(user: UserAttributes(data: ["onboarded": .bool(true)]))
    }

    func saveOnboardingAnswers(_ answers: OnboardingAnswers) async throws {
        let id = try await client.auth.session.user.id
        do {
            try await client.from("onboarding_answers")
                .insert(OnboardingAnswersRow(userID: id, answers: answers, appVersion: AppVersion.display))
                .execute()
        } catch let error as PostgrestError where error.code == "23505" {
            // Already saved for this account (onboarding ran again): the first answers stand.
        }
    }

    func updateName(_ name: String) async throws -> Account {
        let user = try await client.auth.update(user: UserAttributes(data: ["full_name": .string(name)]))
        // The profiles row keeps the same name for server-side features; the account metadata is
        // what the app reads, so a failure here doesn't undo the rename.
        _ = try? await client.from("profiles").update(["name": name]).eq("id", value: user.id).execute()
        return Self.account(user)
    }

    func updateSpecialty(_ specialty: Specialty?) async throws -> Account {
        let value: AnyJSON = specialty.map { .string($0.rawValue) } ?? .null
        return Self.account(try await client.auth.update(user: UserAttributes(data: ["specialty": value])))
    }

    func updatePhoto(_ picked: Data) async throws -> Account {
        guard let jpeg = AvatarImage.jpeg(from: picked) else {
            throw AuthServiceError(message: "That photo couldn\u{2019}t be read. Try another one.")
        }
        let id = try await client.auth.session.user.id.uuidString.lowercased()
        let path = "\(id)/avatar.jpg"
        let avatars = client.storage.from("avatars")
        try await avatars.upload(path, data: jpeg, options: FileOptions(cacheControl: "60", contentType: "image/jpeg", upsert: true))
        // Same path every time, so the URL carries a version: apps and the CDN fetch the new photo.
        let url = try avatars.getPublicURL(path: path, cacheNonce: String(Int(Date.now.timeIntervalSince1970)))
        let user = try await client.auth.update(user: UserAttributes(data: ["avatar_url": .string(url.absoluteString)]))
        return Self.account(user)
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
        let photo = (metadata["avatar_url"] ?? metadata["picture"])?.stringValue.flatMap(URL.init(string:))
        return Account(id: user.id.uuidString, email: user.email, name: name, provider: provider, createdAt: user.createdAt,
                       avatarURL: photo, specialty: metadata["specialty"]?.stringValue.flatMap(Specialty.init(rawValue:)),
                       onboarded: metadata["onboarded"]?.boolValue ?? false)
    }
}

private struct DeleteReply: Decodable { let deleted: Bool }

private struct WelcomeReply: Decodable { let sent: Bool }

private struct ErrorReply: Decodable { let error: String }
