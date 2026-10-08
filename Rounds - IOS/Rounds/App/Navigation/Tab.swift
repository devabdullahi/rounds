import SwiftUI

enum Tab: CaseIterable {
    case today, patients, cards, profile

    var title: String {
        switch self {
        case .today: "Today"
        case .patients: "Patients"
        case .cards: "Flashcards"
        case .profile: "Profile"
        }
    }

    var glyph: IconGlyph {
        switch self {
        case .today: .hospital
        case .patients: .patientChart
        case .cards: .cards
        case .profile: .user
        }
    }
}
