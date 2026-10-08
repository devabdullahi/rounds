import AuthenticationServices
import CryptoKit
import GoogleSignIn
import UIKit

/// Google isn't set up in this build (no client ID in Secrets.xcconfig).
struct GoogleNotConfigured: LocalizedError {
    var errorDescription: String? { "Google sign-in isn't set up in this build yet." }
}
