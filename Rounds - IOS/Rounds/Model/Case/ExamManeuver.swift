import Foundation

/// An exam maneuver on the menu. Its finding arrives from the server when performed.
struct ExamManeuver: Identifiable, Hashable {
    let id: String
    let title: String
}
