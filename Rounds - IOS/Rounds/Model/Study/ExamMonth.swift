import Foundation

/// When the student's exam is, as a month (students book a month, rarely a day), asked in
/// onboarding when their goal is an exam. Drives the countdown and the plan's patient count.
/// Stored as "yyyy-MM"; "later" means past the months offered. Pure, so the counting is tested.
struct ExamMonth: Equatable, Hashable {
    static let storageKey = "examMonth"
    static let later = "later"

    let year: Int
    let month: Int

    /// The next `count` months, starting with the current one.
    static func upcoming(from now: Date = .now, count: Int = 5, calendar: Calendar = .current) -> [ExamMonth] {
        (0..<count).compactMap { offset in
            calendar.date(byAdding: .month, value: offset, to: now).map {
                ExamMonth(year: calendar.component(.year, from: $0), month: calendar.component(.month, from: $0))
            }
        }
    }

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    /// Reads the stored value; nil for "later", nothing, or something unknown.
    init?(stored: String) {
        let parts = stored.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2, (1...12).contains(parts[1]) else { return nil }
        self.init(year: parts[0], month: parts[1])
    }

    var stored: String { String(format: "%04d-%02d", year, month) }

    /// "Dec", for the month picker.
    func shortName(calendar: Calendar = .current) -> String {
        calendar.shortMonthSymbols[month - 1]
    }

    /// "December", for sentences.
    func name(calendar: Calendar = .current) -> String {
        calendar.monthSymbols[month - 1]
    }

    /// Whole weeks from now to the middle of the exam month, never below 1.
    func weeksLeft(from now: Date = .now, calendar: Calendar = .current) -> Int {
        guard let mid = calendar.date(from: DateComponents(year: year, month: month, day: 15)) else { return 1 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: mid).day ?? 0
        return max(1, days / 7)
    }

    /// Patients seen by test day at `perDay` a day.
    func patients(perDay: Int, from now: Date = .now, calendar: Calendar = .current) -> Int {
        weeksLeft(from: now, calendar: calendar) * 7 * perDay
    }
}
