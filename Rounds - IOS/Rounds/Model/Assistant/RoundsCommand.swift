import Foundation

/// What a free-form request to Rounds ("queue me a heme patient") comes down to: one of the app's
/// actions, with the topic and card count it named. Nil topic or count means "use the default".
enum RoundsCommand: Equatable, Sendable {
    case startPatient(StudyFocus?)
    case queuePatient(StudyFocus?)
    case makeCards(StudyFocus?, count: Int?)
    case reviewMistakes(count: Int?)
    case streak
    /// Nothing Rounds can do was recognized.
    case unclear

    /// Deck sizes the server takes; a spoken number snaps to the nearest one.
    static let cardCounts = [10, 20, 30, 50]
    static func snapCount(_ n: Int) -> Int {
        cardCounts.min { abs($0 - n) < abs($1 - n) } ?? 20
    }
}
