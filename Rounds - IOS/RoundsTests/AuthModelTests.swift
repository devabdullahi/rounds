import Foundation
import Testing
@testable import Rounds

/// The account rules behind the signed-out screens and Settings, against a scripted service.
@MainActor
@Suite(.serialized)
struct AuthModelTests {
    private let account = Account(id: "u1", email: "sam@school.edu", name: "Sam Rivera", provider: "email",
                                  createdAt: Date(timeIntervalSince1970: 0))

    /// A private store per test, so the app host's own launch can't touch the flag under test.
    private let defaults = UserDefaults(suiteName: "AuthModelTests.\(UUID().uuidString)")!

    @Test func sendingACodeStartsTheResendClock() async {
        let auth = AuthModel(service: ScriptedAuth(), defaults: defaults)
        #expect(await auth.sendCode(email: " Sam@School.edu ") == "sam@school.edu")
        #expect(auth.codeSentAt != nil)
        #expect(auth.resendWait() > 0)
        #expect(auth.problem == nil)
    }

    @Test func askingAgainDuringTheWaitDoesNotSendAnotherCode() async {
        let service = ScriptedAuth()
        let auth = AuthModel(service: service, defaults: defaults)
        _ = await auth.sendCode(email: "sam@school.edu")
        #expect(await auth.sendCode(email: "SAM@school.edu") == "sam@school.edu")   // same address, still waiting
        _ = await auth.sendCode(email: "other@school.edu")                        // a different address goes out
        #expect(await service.sent.count == 2)
    }

    @Test func aCodeSentMomentsAgoStillLeadsToTheCodeScreen() async {
        let auth = AuthModel(service: ScriptedAuth(send: .failure(CodeRecentlySent(wait: 41))), defaults: defaults)
        #expect(await auth.sendCode(email: "sam@school.edu") == "sam@school.edu")
        #expect(auth.problem == nil)
        #expect((40...41).contains(auth.resendWait()))
    }

    @Test func aRefusedCodeRequestExplainsWhy() async {
        let failing = ScriptedAuth(send: .failure(CaseServiceError(message: "There's no Rounds account for that email.")))
        let auth = AuthModel(service: failing, defaults: defaults)
        #expect(await auth.sendCode(email: "new@school.edu") == nil)
        #expect(auth.codeSentAt == nil)
        #expect(auth.problem == "There's no Rounds account for that email.")
    }

    @Test func theRightCodeSignsIn() async {
        let auth = AuthModel(service: ScriptedAuth(signIn: .success(account)), defaults: defaults)
        #expect(await auth.verifyCode(email: "sam@school.edu", code: "123456") == account)
        #expect(auth.account == account)
        #expect(auth.codeProblem == nil)
        #expect(defaults.bool(forKey: AuthModel.signedInKey) == false)   // onboarding decides when to enter
    }

    @Test func otherVerifyFailuresAreAlertsNotCodeErrors() async {
        let auth = AuthModel(service: ScriptedAuth(signIn: .failure(URLError(.notConnectedToInternet))), defaults: defaults)
        #expect(await auth.verifyCode(email: "sam@school.edu", code: "123456") == nil)
        #expect(auth.codeProblem == nil)
        #expect(auth.problem != nil)
    }

    @Test func finishingOnboardingIsRecordedOnTheAccount() async {
        let service = ScriptedAuth(signIn: .success(account))
        let auth = AuthModel(service: service, defaults: defaults)
        _ = await auth.verifyCode(email: "sam@school.edu", code: "123456")
        auth.finishOnboarding()
        #expect(auth.account?.onboarded == true)
        #expect(defaults.bool(forKey: AuthModel.signedInKey) == true)
        await service.onboarded.waitFor(1)
        #expect(await service.onboarded.count == 1)
    }

    @Test func aWrongCodeStaysOnTheCodeScreen() async {
        let auth = AuthModel(service: ScriptedAuth(signIn: .failure(CodeRejected())), defaults: defaults)
        #expect(await auth.verifyCode(email: "sam@school.edu", code: "000000") == nil)
        #expect(auth.codeProblem == AuthModel.codeRejectedMessage)
        #expect(auth.problem == nil)   // inline, not an alert
        #expect(defaults.bool(forKey: AuthModel.signedInKey) == false)
    }

    @Test(arguments: ["123", "abcdef", "12 456"])
    func malformedCodesAreNotSent(code: String) async {
        let auth = AuthModel(service: ScriptedAuth(signIn: .success(account)), defaults: defaults)
        #expect(await auth.verifyCode(email: "sam@school.edu", code: code) == nil)
        #expect(auth.account == nil)
    }

    @Test func deletingTheAccountSignsOut() async {
        defaults.set(true, forKey: AuthModel.signedInKey)
        let auth = AuthModel(service: ScriptedAuth(signIn: .success(account)), defaults: defaults)
        _ = await auth.verifyCode(email: "sam@school.edu", code: "123456")
        #expect(await auth.deleteAccount() == true)
        #expect(auth.account == nil)
        #expect(defaults.bool(forKey: AuthModel.signedInKey) == false)
    }

    @Test func everySignInAsksForTheWelcomeEmail() async {
        let service = ScriptedAuth(signIn: .success(account))
        let auth = AuthModel(service: service, defaults: defaults)
        _ = await auth.verifyCode(email: "sam@school.edu", code: "123456")
        await service.welcomes.waitFor(1)
        #expect(await service.welcomes.count == 1)
    }

    @Test func renamingSavesTheCleanedName() async {
        let auth = AuthModel(service: ScriptedAuth(signIn: .success(account)), defaults: defaults)
        _ = await auth.verifyCode(email: "sam@school.edu", code: "123456")
        #expect(await auth.rename("  Samira   Rivera ") == true)
        #expect(auth.account?.name == "Samira Rivera")
    }

    @Test func savingTheProfileUpdatesNameAndSpecialty() async {
        let auth = AuthModel(service: ScriptedAuth(signIn: .success(account)), defaults: defaults)
        _ = await auth.verifyCode(email: "sam@school.edu", code: "123456")
        #expect(await auth.saveProfile(name: " Sam  R ", specialty: .pediatrics) == true)
        #expect(auth.account?.name == "Sam R")
        #expect(auth.account?.specialty == .pediatrics)
    }

    @Test func theProfileNeedsAName() async {
        let auth = AuthModel(service: ScriptedAuth(signIn: .success(account)), defaults: defaults)
        _ = await auth.verifyCode(email: "sam@school.edu", code: "123456")
        #expect(await auth.saveProfile(name: "  ", specialty: .pediatrics) == false)
        #expect(auth.problem == "Add your name.")
        #expect(auth.account?.specialty == nil)
    }

    @Test func aBlankNameIsNotSaved() async {
        let auth = AuthModel(service: ScriptedAuth(signIn: .success(account)), defaults: defaults)
        _ = await auth.verifyCode(email: "sam@school.edu", code: "123456")
        #expect(await auth.rename("   ") == false)
        #expect(auth.account?.name == "Sam Rivera")
    }

    @Test func noBackendMeansNothingHappens() async {
        let auth = AuthModel(service: nil, defaults: defaults)
        #expect(await auth.sendCode(email: "a@b.co") == nil)
        #expect(auth.problem == nil)
    }

    @Test(arguments: [("Sam Rivera", nil, "SR"), (nil, "sam.rivera@school.edu", "SR"), (nil, nil, "?")])
    func initialsComeFromTheNameOrEmail(name: String?, email: String?, expected: String) {
        #expect(Account(id: "u", email: email, name: name, provider: "email", createdAt: .now).initials == expected)
    }
}

/// Counts welcome requests; the model sends them from a background task, so tests wait for it.
private actor Counter {
    private(set) var count = 0
    func increment() { count += 1 }
    func waitFor(_ n: Int) async {
        for _ in 0..<100 where count < n { try? await Task.sleep(for: .milliseconds(10)) }
    }
}

/// An auth service that answers from a script.
private struct ScriptedAuth: AuthService {
    let welcomes = Counter()
    let onboarded = Counter()
    let sent = Counter()
    let profile = SavedProfile()
    var signIn: Result<Account, Error> = .failure(URLError(.notConnectedToInternet))
    var send: Result<Void, Error> = .success(())

    func currentAccount() async -> Account? { nil }
    func sendCode(email: String, name: String?) async throws { try send.get(); await sent.increment() }
    func verifyCode(email: String, code: String) async throws -> Account { try signIn.get() }
    func signInWithApple(idToken: String, nonce: String, name: String?) async throws -> Account { try signIn.get() }
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> Account { try signIn.get() }
    func handle(url: URL) async throws -> Account? { nil }
    func signOut() async throws {}
    func deleteAccount() async throws {}
    func sendWelcome() async throws { await welcomes.increment() }
    func markOnboarded() async throws { await onboarded.increment() }
    func updateName(_ name: String) async throws -> Account {
        await profile.set(name: name)
        return await profile.applied(to: try signIn.get())
    }
    func updatePhoto(_ picked: Data) async throws -> Account { try signIn.get() }
    func updateSpecialty(_ specialty: Specialty?) async throws -> Account {
        await profile.set(specialty: specialty)
        return await profile.applied(to: try signIn.get())
    }
}
