import Foundation

/// Where new patients are met. OSCEs at most schools are outpatient only, so a student can limit
/// cases to conditions seen in an office, or to the ward, ED and ICU. The server filters the
/// catalog by each condition's setting tags and sets the encounter there.
enum CareSetting: String, CaseIterable, Identifiable {
    case any = ""
    case clinic
    case hospital

    static let storageKey = "careSetting"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .any: "Any"
        case .clinic: "Clinic"
        case .hospital: "Hospital"
        }
    }

    /// One line under the picker, so "Clinic" reads as the OSCE choice.
    var detail: String {
        switch self {
        case .any: "Office and hospital patients."
        case .clinic: "Office visits only, like an OSCE."
        case .hospital: "Ward, ED and ICU patients only."
        }
    }

    /// The stored choice; anything unknown reads as `.any`.
    init(stored: String) { self = CareSetting(rawValue: stored) ?? .any }

    /// The student's current choice, for models that start cases outside a view.
    static var current: CareSetting {
        CareSetting(stored: UserDefaults.standard.string(forKey: storageKey) ?? "")
    }
}
