import Foundation
import Testing
@testable import Rounds

/// Onboarding's pure rules: the hold-to-promise heart and the stored study goal.
struct OnboardingTests {
    @Test func holdingTheFullTimeCompletes() {
        let frame = 1.0 / 60
        var heart = HoldToCommit()
        var frames = 0
        while !heart.isDone && frames < 1_000 {
            heart.advance(by: frame, holding: true)
            frames += 1
        }
        #expect(heart.isDone && heart.progress == 1)
        #expect(abs(Double(frames) - HoldToCommit.fillSeconds / frame) <= 1)
    }

    @Test func lettingGoEarlyDrainsBackToEmpty() {
        var heart = HoldToCommit()
        heart.advance(by: 0.8, holding: true)
        #expect(heart.progress > 0.4 && heart.progress < 0.6)
        heart.advance(by: 0.4, holding: false)
        #expect(heart.progress == 0)
        #expect(!heart.isDone)
        #expect(heart.isSettled(holding: false))
    }

    @Test func aFullHeartStaysFull() {
        var heart = HoldToCommit()
        heart.advance(by: HoldToCommit.fillSeconds, holding: true)
        #expect(heart.advance(by: 1, holding: false) == false)
        #expect(heart.progress == 1)
    }

    @Test(arguments: [(0.0, 0), (0.3, 1), (0.55, 2), (0.8, 3), (1.2, 4)])
    func quarterMarks(held: Double, quarter: Int) {
        var heart = HoldToCommit()
        heart.advance(by: held * HoldToCommit.fillSeconds, holding: true)
        #expect(heart.quarter == quarter)
    }

    @Test func voiceOverCanCompleteWithoutHolding() {
        var heart = HoldToCommit()
        heart.complete()
        #expect(heart.isDone && heart.progress == 1)
    }

    @Test(arguments: StudyGoal.allCases)
    func studyGoalRoundTrips(goal: StudyGoal) {
        #expect(StudyGoal(stored: goal.rawValue) == goal)
    }

    @Test func unknownStudyGoalReadsAsNone() {
        #expect(StudyGoal(stored: "") == nil)
        #expect(StudyGoal(stored: "mcat") == nil)
    }
}

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
