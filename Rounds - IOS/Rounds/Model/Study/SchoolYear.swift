import Foundation

/// The student's year of medical school, asked once during onboarding. Stored for steering case
/// difficulty later; students still browse by topic (`StudyFocus`), never by year.
enum SchoolYear: String, CaseIterable, Identifiable {
    case ms1, ms2, ms3, ms4

    static let storageKey = "schoolYear"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ms1: "MS1"
        case .ms2: "MS2"
        case .ms3: "MS3"
        case .ms4: "MS4"
        }
    }

    /// Reads the stored raw value; nil when nothing (or something unknown) was saved.
    init?(stored: String) { self.init(rawValue: stored) }
}
