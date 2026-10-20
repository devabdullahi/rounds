import Foundation

/// How many cases a day the student aims for, asked during onboarding. Home shows today's count
/// against it.
enum DailyGoal: Int, CaseIterable, Identifiable {
    case one = 1, two = 2, three = 3, five = 5

    static let storageKey = "dailyGoal"
    static let `default` = DailyGoal.two

    var id: Int { rawValue }
    var cases: Int { rawValue }

    var label: String { cases == 1 ? "1 case" : "\(cases) cases" }
    /// A typical case takes about ten minutes.
    var duration: String { "About \(cases * 10) min" }

    /// Reads the stored value; anything unknown (or nothing yet) is the default.
    init(stored: Int) { self = DailyGoal(rawValue: stored) ?? .default }
}
