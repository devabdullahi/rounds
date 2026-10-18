import Foundation
import Observation

/// Accounts for the signed-out screens and Settings: who's signed in, what's in progress, and the
/// one place the app switches between the account flow and the app (`signedInKey`).
@MainActor
@Observable
final class AuthModel {
    /// The app shows its tabs when this is true (read with @AppStorage by RootView).
    nonisolated static let signedInKey = "signedIn"

    static let codeRejectedMessage = "That code isn\u{2019}t right or has expired. Check the newest email, or send a new code."

    enum Busy: Equatable { case email, apple, google, signOut, delete, name, photo }

    private let service: (any AuthService)?
    /// Where the signed-in flag lives: standard in the app, a private store in tests.
    private let defaults: UserDefaults
    private(set) var account: Account?
    private(set) var busy: Busy?
    /// The provider whose sign-in sheet is open, for the Apple/Google buttons.
    var signingInWith: SocialProvider? {
        switch busy {
        case .apple?: .apple
        case .google?: .google
        default: nil
        }
    }
    /// Shown as an alert by the screen that started the action.
    var problem: String?
    /// When the last code was emailed, and to whom: drives the resend countdown, which also holds
    /// if the student goes back and asks again for the same address.
    private(set) var codeSentAt: Date?
    private var codeSentTo: String?
    /// The code screen's inline message after a wrong or expired code.
    private(set) var codeProblem: String?
    /// Set while sign-in waits on the student: this sign-in looks like a second account, and this
    /// is the account the device used before. The root view asks and answers with `choose(_:)`.
    private(set) var duplicate: KnownAccount?
    @ObservationIgnored private var duplicateAnswer: CheckedContinuation<DuplicateChoice, Never>?

    init(service: (any AuthService)?, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
    }

    /// On launch: picks up a session the SDK kept in the keychain.
    func restore() async {
        account = await service?.currentAccount()
    }

    /// Emails a sign-in code. Pass `name` when creating an account (sign up); leave it nil to log in.
    /// Returns the normalized address the code went to (the code screen's key), or nil when it
    /// wasn't sent. Within the resend wait for the same address, the code already on its way counts.
    func sendCode(email: String, name: String? = nil) async -> String? {
        let address = EmailAddress.normalized(email)
        if address == codeSentTo && resendWait() > 0 { return address }
        var sentAt = Date.now
        let sent = await run(.email) { service in
            do {
                try await service.sendCode(email: address, name: name?.trimmed)
            } catch let recent as CodeRecentlySent {
                // Sent within the last minute (another tap, or before the app restarted).
                sentAt = .now.addingTimeInterval(recent.wait - EmailCode.resendAfter)
            }
            return true
        } ?? false
        guard sent else { return nil }
        codeSentAt = sentAt
        codeSentTo = address
        codeProblem = nil
        return address
    }

    /// Whole seconds before another code can be sent.
    func resendWait(now: Date = .now) -> Int { EmailCode.resendWait(sentAt: codeSentAt, now: now) }

    /// The student started typing a new code: the old error no longer applies.
    func clearCodeProblem() { codeProblem = nil }

    /// Signs in with the emailed code. Nil when it failed: a wrong or expired code is explained in
    /// `codeProblem` (shown on the code screen), anything else in `problem`.
    func verifyCode(email: String, code: String) async -> Account? {
        guard EmailCode.isComplete(code), EmailCode.clean(code) == code else { return nil }
        codeProblem = nil
        return await run(.email) { service in
            do {
                let account = try await service.verifyCode(email: email.trimmed, code: code)
                self.remember(account)
                self.account = account
                self.welcome()
                return account
            } catch is CodeRejected {
                self.codeProblem = Self.codeRejectedMessage
                return nil
            }
        } ?? nil
    }

    /// Apple's or Google's sheet, then Supabase. Nil when cancelled or failed (the failure is in
    /// `problem`). An account that hasn't finished onboarding still needs it: see `Account.onboarded`.
    ///
    /// When this sign-in just made a new account but the device knows an earlier one from the other
    /// provider, it pauses on `duplicate` until the student chooses. Moving onto the earlier account
    /// removes the empty new one, signs into the earlier one (its sheet), then links this provider
    /// to it (this sheet again), so both buttons open the same account from then on.
    func continueWith(_ provider: SocialProvider) async -> Account? {
        await run(provider == .apple ? .apple : .google) { service in
            var account = try await Self.signIn(provider, service)
            if let earlier = KnownAccount.duplicate(of: self.lastAccount, signedIn: account),
               let earlierProvider = earlier.socialProvider,
               await self.ask(about: earlier) == .useEarlier {
                // The new account is empty (made seconds ago, never onboarded), so nothing is lost.
                try await service.deleteAccount()
                self.account = nil
                _ = try await Self.signIn(earlierProvider, service)
                account = try await Self.link(provider, service)
            }
            self.remember(account)
            self.account = account
            self.welcome()
            return account
        }
    }

    /// The root view's answer to `duplicate`.
    func choose(_ choice: DuplicateChoice) {
        duplicate = nil
        duplicateAnswer?.resume(returning: choice)
        duplicateAnswer = nil
    }

    private func ask(about earlier: KnownAccount) async -> DuplicateChoice {
        await withCheckedContinuation { answer in
            duplicateAnswer = answer
            duplicate = earlier
        }
    }

    private static func signIn(_ provider: SocialProvider, _ service: any AuthService) async throws -> Account {
        switch provider {
        case .apple:
            let apple = try await AppleSignIn().signIn()
            return try await service.signInWithApple(idToken: apple.idToken, nonce: apple.nonce, name: apple.name)
        case .google:
            let google = try await GoogleAuth.signIn()
            return try await service.signInWithGoogle(idToken: google.idToken, accessToken: google.accessToken)
        }
    }

    private static func link(_ provider: SocialProvider, _ service: any AuthService) async throws -> Account {
        switch provider {
        case .apple:
            let apple = try await AppleSignIn().signIn()
            return try await service.linkApple(idToken: apple.idToken, nonce: apple.nonce)
        case .google:
            let google = try await GoogleAuth.signIn()
            return try await service.linkGoogle(idToken: google.idToken, accessToken: google.accessToken)
        }
    }

    /// The account this device last signed in with, kept across sign-outs (see `KnownAccount`).
    private var lastAccount: KnownAccount? {
        defaults.data(forKey: KnownAccount.storageKey).flatMap { try? JSONDecoder().decode(KnownAccount.self, from: $0) }
    }

    private func remember(_ account: Account) {
        if let data = try? JSONEncoder().encode(KnownAccount(account)) { defaults.set(data, forKey: KnownAccount.storageKey) }
    }

    /// A link the app was opened with: Google's sheet returning, or an email link.
    /// True when it finished signing in.
    func open(_ url: URL) async -> Bool {
        if GoogleAuth.handle(url) { return false }
        let account = await run(.email) { service in try await service.handle(url: url) } ?? nil
        guard let account else { return false }
        self.account = account
        welcome()
        finishSignIn()
        return true
    }

    /// Into the app (after onboarding, for a new account).
    func finishSignIn() {
        defaults.set(true, forKey: Self.signedInKey)
    }

    /// Saves a new name. False when there was nothing to save or it failed (the reason is in `problem`).
    func rename(_ typed: String) async -> Bool {
        guard account != nil, let name = ProfileName.clean(typed) else { return false }
        guard name != account?.name else { return true }
        return await run(.name) { service in
            self.account = try await service.updateName(name)
            return true
        } ?? false
    }

    /// Saves the profile sheet: name (required) and specialty. Only what changed is sent.
    func saveProfile(name typed: String, specialty: Specialty?) async -> Bool {
        guard account != nil else { return false }
        guard let name = ProfileName.clean(typed) else {
            problem = "Add your name."
            return false
        }
        return await run(.name) { service in
            if name != self.account?.name { self.account = try await service.updateName(name) }
            if specialty != self.account?.specialty { self.account = try await service.updateSpecialty(specialty) }
            return true
        } ?? false
    }

    /// Sets the profile photo from a picked image. False when it couldn't be read or uploaded.
    func setPhoto(_ picked: Data) async -> Bool {
        guard account != nil else { return false }
        return await run(.photo) { service in
            self.account = try await service.updatePhoto(picked)
            return true
        } ?? false
    }

    /// End of onboarding: recorded on the account (so no device asks again), then into the app.
    /// Recording is best effort; if it fails, the student simply sees onboarding again next time.
    func finishOnboarding() {
        if let service { Task { try? await service.markOnboarded() } }
        if let account { self.account = account.markedOnboarded() }
        finishSignIn()
    }

    /// Asks for the welcome email after every sign-in, whatever the provider. The server sends it
    /// only once per account, so returning students get nothing new. It's a courtesy: a failure
    /// never holds the student up or shows an error.
    private func welcome() {
        guard let service else { return }
        Task { try? await service.sendWelcome() }
    }

    func signOut() async {
        _ = await run(.signOut) { service in try await service.signOut() }
        leave()
    }

    /// True when the account and its data are gone.
    func deleteAccount() async -> Bool {
        let done = await run(.delete) { service in try await service.deleteAccount(); return true } ?? false
        if done {
            // A deleted account can't be offered again.
            if lastAccount?.id == account?.id { defaults.removeObject(forKey: KnownAccount.storageKey) }
            leave()
        }
        return done
    }

    private func leave() {
        account = nil
        codeSentAt = nil
        codeSentTo = nil
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

private extension Account {
    func markedOnboarded() -> Account {
        var copy = self
        copy.onboarded = true
        return copy
    }
}

#if DEBUG
extension AuthModel {
    /// `-screen email-code-error`: shows the wrong-code state without a server.
    func debugRejectCode() { codeProblem = Self.codeRejectedMessage }

    /// `-screen settings`: a signed-in account for screenshots, without a server.
    func debugUse(_ sample: Account) { account = sample }

    /// `-screen duplicate-account`: the earlier-account prompt, without signing in.
    func debugOfferDuplicate() { duplicate = KnownAccount(id: "debug", provider: "google", maskedEmail: "m•••@school.edu") }
}
#endif
