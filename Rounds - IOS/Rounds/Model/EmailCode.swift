import Foundation

/// Rules for the 6-digit code Rounds emails instead of a password: what counts as typed,
/// when it's complete, and how long before another can be sent. `length` and `validMinutes`
/// match `otp_length` and `otp_expiry` in supabase/config.toml.
enum EmailCode {
    static let length = 6
    static let validMinutes = 10
    /// Seconds before "Resend" unlocks, so a slow inbox doesn't trigger a pile of codes.
    static let resendAfter: TimeInterval = 60

    /// Digits only, at most six: pasted codes ("123 456") and Mail's autofill both land clean.
    static func clean(_ typed: String) -> String {
        String(typed.filter(\.isASCIIDigit).prefix(length))
    }

    static func isComplete(_ code: String) -> Bool { code.count == length }

    /// Whole seconds left before a new code can be sent; 0 when it can be sent now.
    static func resendWait(sentAt: Date?, now: Date = .now) -> Int {
        guard let sentAt else { return 0 }
        return max(0, Int((resendAfter - now.timeIntervalSince(sentAt)).rounded(.up)))
    }

    /// "0:42" for the resend countdown.
    static func clock(_ seconds: Int) -> String {
        "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }
}

private extension Character {
    /// 0–9 only: keycaps ("1️⃣") and other scripts' digits aren't part of a code.
    var isASCIIDigit: Bool { isASCII && isWholeNumber }
}

