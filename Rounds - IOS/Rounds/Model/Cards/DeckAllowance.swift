import Foundation

/// Generated decks left today, as the server last reported. Limits reset at midnight UTC, so a
/// count from an earlier UTC day no longer applies.
struct DeckAllowance: Equatable, Sendable {
    let remaining: Int
    let limit: Int
    var asOf: Date = .now

    /// Still describes today (UTC).
    func isCurrent(now: Date = .now) -> Bool {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return utc.isDate(asOf, inSameDayAs: now)
    }

    /// "2 of 3 decks left today".
    var label: String { "\(remaining) of \(limit) deck\(limit == 1 ? "" : "s") left today" }
}
