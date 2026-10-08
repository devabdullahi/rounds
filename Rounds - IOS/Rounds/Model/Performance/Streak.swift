import Foundation

/// Day streaks from graded cases. Finishing a case keeps the streak alive for 24 hours; a gap of
/// more than 24 hours between cases (or since the last one) resets it. The streak counts the
/// distinct days, in the student's calendar, that the unbroken run covers.
enum Streak {
    /// Longest gap between cases that keeps a streak going.
    static let window: TimeInterval = 24 * 60 * 60
    /// Weeks of colour the streak pill steps through, one per 7 days, then repeats.
    static let weekColorCount = 5
    /// Days for the flame to grow from its first flicker to full size.
    static let daysToFullHeat = 21

    /// Days in the current run; 0 when the last case was more than 24 hours ago.
    static func current(_ dates: [Date], now: Date = .now, calendar: Calendar = .current) -> Int {
        let newestFirst = dates.sorted(by: >)
        guard let latest = newestFirst.first, now.timeIntervalSince(latest) <= window else { return 0 }
        var run = [latest]
        for date in newestFirst.dropFirst() {
            guard let last = run.last, last.timeIntervalSince(date) <= window else { break }
            run.append(date)
        }
        return Set(run.map { calendar.startOfDay(for: $0) }).count
    }

    /// The longest run ever, in days.
    static func best(_ dates: [Date], calendar: Calendar = .current) -> Int {
        let oldestFirst = dates.sorted()
        var best = 0
        var run: [Date] = []
        for date in oldestFirst {
            if let last = run.last, date.timeIntervalSince(last) > window { run = [] }
            run.append(date)
            best = max(best, Set(run.map { calendar.startOfDay(for: $0) }).count)
        }
        return best
    }

    /// Which colour a streak shows: 0 for days 0–6, 1 for 7–13 …, cycling after the last.
    static func weekColorIndex(_ days: Int) -> Int { (max(0, days) / 7) % weekColorCount }

    /// How hot the flame burns, 0 (no streak, cold) to 1, growing a little each day.
    static func heat(_ days: Int) -> Double { min(1, Double(max(0, days)) / Double(daysToFullHeat)) }
}
