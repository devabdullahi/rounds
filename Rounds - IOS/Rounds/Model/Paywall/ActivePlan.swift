import Foundation

/// The plan a student holds now, for Settings: what it is, where it was bought (which decides
/// where it's managed), and when it renews or ends.
struct ActivePlan: Equatable, Sendable {
    enum Source: Sendable, Equatable {
        /// Bought in the app; managed in Apple's subscription sheet.
        case appStore
        /// Bought on the web; managed in Stripe's billing portal.
        case web
    }

    let source: Source
    let period: SubscriptionPlan.Period
    /// When the current period (or the trial) ends.
    let periodEnd: Date
    let isTrial: Bool
    /// Cancelled: access lasts until `periodEnd`, then stops.
    let willRenew: Bool

    /// "Yearly · renews Oct 14, 2027", "Free trial · ends Oct 14", "Monthly · ends Nov 2, 2026".
    func summary(locale: Locale = .current, calendar: Calendar = .current, now: Date = .now) -> String {
        let sameYear = calendar.component(.year, from: periodEnd) == calendar.component(.year, from: now)
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.abbreviated).day()
        let date = periodEnd.formatted(sameYear ? style : style.year())
        if isTrial { return "Free trial · \(willRenew ? "then \(period.name.lowercased()) from" : "ends") \(date)" }
        return "\(period.name) · \(willRenew ? "renews" : "ends") \(date)"
    }

    /// Where the student goes to cancel or change it, said plainly.
    var manageHint: String {
        switch source {
        case .appStore: "Billed by Apple"
        case .web: "Billed on the web"
        }
    }
}
