import Foundation

/// User-pickable card colours, stored by raw value. Their look lives with the flashcard views.
enum CardColor: String, CaseIterable, Identifiable, Sendable {
    case standard, teal, blue, purple, pink, red, yellow
    var id: String { rawValue }
    var name: String { self == .standard ? "Default" : rawValue.capitalized }
}
