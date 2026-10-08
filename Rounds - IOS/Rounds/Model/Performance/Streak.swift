import Foundation

/// Day streaks from graded cases: a day counts when at least one case was graded on it (the
/// student's own calendar). The current streak stays alive through today, so a student who
/// studied yesterday still sees it until midnight; one missed day ends it.
enum Streak {
    /// Weeks of colour the streak pill steps through, one per 7 days, then repeats.
    static let weekColorCount = 5

    /// Consecutive days with a graded case, ending today or yesterday; 0 otherwise.
    static func current(_ dates: [Date], now: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
        var day = days.contains(today) ? today : yesterday
        var count = 0
        while days.contains(day), let previous = calendar.date(byAdding: .day, value: -1, to: day) {
            count += 1
            day = previous
        }
        return count
    }

    /// The longest run of consecutive days ever.
    static func best(_ dates: [Date], calendar: Calendar = .current) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) }).sorted()
        var best = 0, run = 0
        var last: Date?
        for day in days {
            if let last, calendar.date(byAdding: .day, value: 1, to: last) == day { run += 1 } else { run = 1 }
            best = max(best, run)
            last = day
        }
        return best
    }

    /// Which colour a streak shows: 0 for days 0–6, 1 for 7–13 …, cycling after the last.
    static func weekColorIndex(_ days: Int) -> Int { (max(0, days) / 7) % weekColorCount }
}
