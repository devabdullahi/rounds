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

    /// The tag on the onboarding exam-day graph: the exam's name, or "Exam day" when the goal isn't one.
    var examDayTag: String {
        switch self {
        case .step1, .step2CK, .shelf, .osce: label
        case .other, .practicing: "Exam day"
        }
    }

    /// The care setting onboarding starts this student in: OSCEs at most schools are outpatient
    /// only, so they start in clinic cases. They can change it any time in the Focus sheet.
    var careSetting: CareSetting { self == .osce ? .clinic : .any }

    /// What the debrief's exam lens adds for this goal (the server's `examLens`), said plainly; nil
    /// when the goal has no lens. Onboarding promises only this, so it must match what grading sends.
    var debriefTips: String? {
        switch self {
        case .step2CK, .shelf: "The next best steps for each case"
        case .osce: "The questions that mattered most"
        case .step1: "The complications to know"
        case .other, .practicing: nil
        }
    }

    /// The goal as it reads before "tips": "Step 2 CK tips", "OSCE tips", "Shelf tips".
    var tipsName: String {
        switch self {
        case .shelf: "Shelf"
        case .osce: "OSCE"
        default: label
        }
    }

    /// Reads the stored raw value; nil when nothing (or something unknown) was saved.
    init?(stored: String) { self.init(rawValue: stored) }
}
