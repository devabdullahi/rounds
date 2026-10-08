import Foundation

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
