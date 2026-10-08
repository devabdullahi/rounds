import Foundation

/// What badges are judged on: the student's whole record.
struct BadgeRecord: Sendable {
    var rating: Int
    var bestStreak: Int
    var cases: [GradedCase]
}
