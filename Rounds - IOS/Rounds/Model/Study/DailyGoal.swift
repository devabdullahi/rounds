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

    /// The next pace up (`by: 1`) or down (`by: -1`), or nil past either end.
    func stepped(by: Int) -> DailyGoal? {
        let all = Self.allCases
        guard let i = all.firstIndex(of: self), all.indices.contains(i + by) else { return nil }
        return all[i + by]
    }

    /// Reads the stored value; anything unknown (or nothing yet) is the default.
    init(stored: Int) { self = DailyGoal(rawValue: stored) ?? .default }
}
