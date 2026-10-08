import Foundation

/// The exam (or none) a new student is working toward, asked once during onboarding.
/// It frames their commitment and will steer case difficulty later; topics stay in `StudyFocus`.
enum StudyGoal: String, CaseIterable, Identifiable {
    case step1, step2CK, shelf, osce, other, practicing

    static let storageKey = "studyGoal"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .step1: "Step 1"
        case .step2CK: "Step 2 CK"
        case .shelf: "Shelf exams"
        case .osce: "OSCEs"
        case .other: "Other"
        case .practicing: "Just practicing"
        }
    }

    /// Reads the stored raw value; nil when nothing (or something unknown) was saved.
    init?(stored: String) { self.init(rawValue: stored) }
}
