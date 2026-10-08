import AuthenticationServices
import CryptoKit
import GoogleSignIn
import UIKit

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

@MainActor
private func topViewController() -> UIViewController? {
    var top = keyWindow()?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
}
