import AuthenticationServices
import CryptoKit
import GoogleSignIn
import UIKit

/// This build isn't signed with the Sign in with Apple capability (free Personal Team).
struct AppleNotAvailable: LocalizedError {
    var errorDescription: String? { "Sign in with Apple isn't available in this build yet. Use Google or email for now." }
}
