import Foundation
import Testing
@testable import Rounds

/// The emailed-code rules behind log in and sign up.
struct EmailCodeTests {
    @Test(arguments: [("123456", "123456"), ("123 456", "123456"), ("12a3-45", "12345"), ("1234567", "123456"), ("", ""),
                      ("1\u{FE0F}\u{20E3}23456", "23456"), ("١٢٣٤٥٦", "")])
    func typedCodesAreCleaned(typed: String, clean: String) {
        #expect(EmailCode.clean(typed) == clean)
    }

    @Test func onlySixDigitsAreComplete() {
        #expect(EmailCode.isComplete("123456"))
        #expect(!EmailCode.isComplete("12345"))
    }

    @Test(arguments: [(0.0, 60), (18.2, 42), (59.5, 1), (60.0, 0), (300.0, 0)])
    func resendCountsDown(elapsed: Double, wait: Int) {
        let sent = Date(timeIntervalSince1970: 1_000)
        #expect(EmailCode.resendWait(sentAt: sent, now: sent.addingTimeInterval(elapsed)) == wait)
    }

    @Test func neverSentMeansNoWait() {
        #expect(EmailCode.resendWait(sentAt: nil) == 0)
    }

    @Test(arguments: [(42, "0:42"), (60, "1:00"), (5, "0:05")])
    func countdownReadsLikeAClock(seconds: Int, label: String) {
        #expect(EmailCode.clock(seconds) == label)
    }

    @Test(arguments: [("sam@school.edu", true), (" sam@school.edu ", true), ("sam@school", false),
                      ("@school.edu", false), ("sam school@x.edu", false), ("sam@.edu", false), ("", false),
                      ("a@b@c.com", false), ("a@b..com", false), ("a\t@b.com", false), ("a\u{00A0}@b.com", false)])
    func emailShapeCheck(typed: String, ok: Bool) {
        #expect(EmailAddress.looksValid(typed) == ok)
    }
}
