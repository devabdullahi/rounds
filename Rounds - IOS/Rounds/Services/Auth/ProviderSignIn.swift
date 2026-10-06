import AuthenticationServices
import CryptoKit
import GoogleSignIn
import UIKit

/// Apple's and Google's own sign-in sheets, as plain async calls that return the tokens Supabase
/// verifies. No UI state here: the auth model decides what happens next.

/// The student closed the sheet. Not an error worth showing.
struct SignInCancelled: Error {}

/// Google isn't set up in this build (no client ID in Secrets.xcconfig).
struct GoogleNotConfigured: LocalizedError {
    var errorDescription: String? { "Google sign-in isn't set up in this build yet." }
}

// MARK: - Apple

@MainActor
final class AppleSignIn: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    struct Result { let idToken: String; let nonce: String; let name: String? }

    private var continuation: CheckedContinuation<Result, Error>?
    private var rawNonce = ""

    /// Shows Apple's sheet. The raw nonce goes to Supabase; Apple gets only its SHA-256, so a
    /// stolen token can't be replayed.
    func signIn() async throws -> Result {
        rawNonce = Self.randomNonce()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(rawNonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        MainActor.assumeIsolated {
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else {
                finish(.failure(URLError(.userAuthenticationRequired)))
                return
            }
            let name = credential.fullName.map { PersonNameComponentsFormatter.localizedString(from: $0, style: .default) }
            finish(.success(Result(idToken: token, nonce: rawNonce, name: name?.isEmpty == true ? nil : name)))
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        MainActor.assumeIsolated {
            let cancelled = (error as? ASAuthorizationError)?.code == .canceled
            finish(.failure(cancelled ? SignInCancelled() : error))
        }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated { keyWindow() ?? ASPresentationAnchor() }
    }

    private func finish(_ result: Swift.Result<Result, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset[Int.random(in: 0..<charset.count, using: &generator)] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Google

@MainActor
enum GoogleAuth {
    /// A client ID is set in Info.plist (from Secrets.xcconfig).
    static var isConfigured: Bool {
        let id = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? ""
        return id.hasSuffix(".apps.googleusercontent.com")
    }

    /// Shows Google's sheet; returns the ID and access tokens Supabase verifies.
    static func signIn() async throws -> (idToken: String, accessToken: String) {
        guard isConfigured else { throw GoogleNotConfigured() }
        guard let presenter = topViewController() else { throw URLError(.cannotLoadFromNetwork) }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else { throw URLError(.userAuthenticationRequired) }
            return (idToken, result.user.accessToken.tokenString)
        } catch let error as NSError where error.domain == kGIDSignInErrorDomain && error.code == GIDSignInError.canceled.rawValue {
            throw SignInCancelled()
        }
    }

    /// Google's sheet returns to the app through its reversed-client-ID URL scheme.
    static func handle(_ url: URL) -> Bool { GIDSignIn.sharedInstance.handle(url) }
}

// MARK: - Presenting

@MainActor
private func keyWindow() -> UIWindow? {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)
}

@MainActor
private func topViewController() -> UIViewController? {
    var top = keyWindow()?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
}
