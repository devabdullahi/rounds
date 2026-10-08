import AuthenticationServices
import CryptoKit
import GoogleSignIn
import UIKit

@MainActor
func keyWindow() -> UIWindow? {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows)
        .first(where: \.isKeyWindow)
}
