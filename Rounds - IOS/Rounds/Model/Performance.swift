import Foundation

/// The six parts every graded case is scored on. They add up to 100; the raw values match the
/// server's grade breakdown keys.
enum ScoreCategory: String, CaseIterable, Identifiable, Sendable {
    case diagnosis, history, exam, redFlags = "red_flags", tests, plan
    var id: String { rawValue }

    var label: String {
        switch self {
        case .diagnosis: "Diagnosis"
        case .history: "History taking"
        case .exam: "Examination"
        case .redFlags: "Red-flag questions"
        case .tests: "Test selection"
        case .plan: "Plan"
        }
    }

    /// What earns these points, so a weak spot says what to practice.
    var detail: String {
        switch self {
        case .diagnosis: "Naming the condition the patient actually has."
        case .history: "Asking the questions a strong student asks, weighted by how much they matter."
        case .exam: "Doing the exam maneuvers that confirm or rule out the diagnosis."
        case .redFlags: "Screening for the dangerous look-alikes you can't afford to miss."
        case .tests: "Ordering the right tests first, skipping ones that don't change management, staying on budget."
        case .plan: "An immediate plan that fits the diagnosis and its severity."
        }
    }
}

/// Points earned out of the most available.
struct Points: Hashable, Sendable {
    var got: Int
    var max: Int
}

/// One submitted, graded case, as the profile's stats and badges read it.
struct GradedCase: Identifiable, Hashable, Sendable {
    let id: String
    let submittedAt: Date
    let score: Int
    let diagnosisCorrect: Bool
    let missedRedFlags: Int
    let clerkship: Clerkship?
    let system: OrganSystem?
    /// Empty for cases graded before the server recorded a breakdown.
    let breakdown: [ScoreCategory: Points]
}

/// How far back the points breakdown looks.
enum Timeframe: String, CaseIterable, Identifiable, Sendable {
    case week, month, all
    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: "7 days"
        case .month: "30 days"
        case .all: "All time"
        }
    }

    func includes(_ date: Date, now: Date) -> Bool {
        switch self {
        case .week: date > now.addingTimeInterval(-7 * 86_400)
        case .month: date > now.addingTimeInterval(-30 * 86_400)
        case .all: true
        }
    }
}

/// One category's totals over a set of cases.
struct CategoryStat: Identifiable, Hashable, Sendable {
    let category: ScoreCategory
    let points: Points
    var id: ScoreCategory { category }
    /// Share of the available points earned, 0…1.
    var share: Double { points.max == 0 ? 1 : Double(points.got) / Double(points.max) }
    var lost: Int { points.max - points.got }
}

enum Performance {
    /// Category totals for the cases in a timeframe, where the most points were lost first, and how
    /// many cases they cover. Cases graded before the breakdown existed are left out.
    static func stats(_ cases: [GradedCase], in timeframe: Timeframe, now: Date = .now) -> (stats: [CategoryStat], cases: Int) {
        let counted = cases.filter { !$0.breakdown.isEmpty && timeframe.includes($0.submittedAt, now: now) }
        let stats = ScoreCategory.allCases.map { category in
            let points = counted.compactMap { $0.breakdown[category] }
                .reduce(Points(got: 0, max: 0)) { Points(got: $0.got + $1.got, max: $0.max + $1.max) }
            return CategoryStat(category: category, points: points)
        }
        .filter { $0.points.max > 0 }
        .sorted { ($0.share, $1.points.max) < ($1.share, $0.points.max) }
        return (stats, counted.count)
    }
}
