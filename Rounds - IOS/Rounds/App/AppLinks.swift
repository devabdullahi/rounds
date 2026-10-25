import Foundation

/// Where Settings › About points. Each row shows only once its link exists.
/// Fill these in before launch: App Store review requires a privacy policy link.
enum AppLinks {
    static let supportEmail: String? = "tryroundsapp@gmail.com"
    static let privacyPolicy: URL? = URL(string: "https://tryroundsapp.com/privacy")
    /// Rounds' own Terms of Use (website/app/public/terms.html), agreed to by creating an account (SignUpTermsNote).
    static let terms: URL? = URL(string: "https://tryroundsapp.com/terms")

    /// "Send feedback" opens a mail draft to support.
    static var feedback: URL? { supportEmail.flatMap { URL(string: "mailto:\($0)") } }
}
