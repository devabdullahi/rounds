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

    @Test func emailSignInSucceeds() async {
        let auth = AuthModel(service: ScriptedAuth(signIn: .success(account)), defaults: defaults)
        #expect(await auth.signIn(email: " sam@school.edu ", password: "pw") == true)
        #expect(auth.account == account)
        #expect(auth.problem == nil)
    }

    @Test func aFailedSignInExplainsWhy() async {
        let failing = ScriptedAuth(signIn: .failure(CaseServiceError(message: "Invalid login credentials")))
        let auth = AuthModel(service: failing, defaults: defaults)
        #expect(await auth.signIn(email: "sam@school.edu", password: "nope") == false)
        #expect(auth.account == nil)
        #expect(auth.problem == "Invalid login credentials")
    }

    @Test func signUpWithConfirmationWaitsForTheLink() async {
        let auth = AuthModel(service: ScriptedAuth(signUp: .confirmEmail("sam@school.edu")), defaults: defaults)
        #expect(await auth.signUp(email: "sam@school.edu", password: "Passw0rd!", name: "Sam") == false)
        #expect(auth.pendingEmail == "sam@school.edu")
        #expect(defaults.bool(forKey: AuthModel.signedInKey) == false)
    }

    @Test func deletingTheAccountSignsOut() async {
        defaults.set(true, forKey: AuthModel.signedInKey)
        let auth = AuthModel(service: ScriptedAuth(signIn: .success(account)), defaults: defaults)
        _ = await auth.signIn(email: "sam@school.edu", password: "pw")
        #expect(await auth.deleteAccount() == true)
        #expect(auth.account == nil)
        #expect(defaults.bool(forKey: AuthModel.signedInKey) == false)
    }

    @Test func noBackendMeansNothingHappens() async {
        let auth = AuthModel(service: nil, defaults: defaults)
        #expect(await auth.signIn(email: "a@b.co", password: "x") == false)
        #expect(auth.problem == nil)
    }

    @Test(arguments: [(10.0, true), (600.0, false)])
    func onlyAFreshAccountNeedsOnboarding(secondsAgo: Double, isNew: Bool) {
        let now = Date(timeIntervalSince1970: 10_000)
        let made = Account(id: "u", email: nil, name: nil, provider: "apple", createdAt: now.addingTimeInterval(-secondsAgo))
        #expect(made.isNew(now: now) == isNew)
    }

    @Test(arguments: [("Sam Rivera", nil, "SR"), (nil, "sam.rivera@school.edu", "SR"), (nil, nil, "?")])
    func initialsComeFromTheNameOrEmail(name: String?, email: String?, expected: String) {
        #expect(Account(id: "u", email: email, name: name, provider: "email", createdAt: .now).initials == expected)
    }
}

/// An auth service that answers from a script.
private struct ScriptedAuth: AuthService {
    var signIn: Result<Account, Error> = .failure(URLError(.notConnectedToInternet))
    var signUp: SignUpOutcome = .confirmEmail("")

    func currentAccount() async -> Account? { nil }
    func signUp(email: String, password: String, name: String) async throws -> SignUpOutcome { signUp }
    func signIn(email: String, password: String) async throws -> Account { try signIn.get() }
    func signInWithApple(idToken: String, nonce: String, name: String?) async throws -> Account { try signIn.get() }
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> Account { try signIn.get() }
    func handle(url: URL) async throws -> Account? { nil }
    func signOut() async throws {}
    func deleteAccount() async throws {}
}
