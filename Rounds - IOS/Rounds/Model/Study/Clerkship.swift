import Foundation

enum Clerkship: String, CaseIterable, Identifiable {
    case internalMedicine, surgery, pediatrics, obgyn, psychiatry, familyMedicine, neurology, emergency, clinicalPsychology, dermatology
    var id: String { rawValue }

    var label: String {
        switch self {
        case .internalMedicine: "Internal medicine"
        case .surgery: "Surgery"
        case .pediatrics: "Pediatrics"
        case .obgyn: "OB/GYN"
        case .psychiatry: "Psychiatry"
        case .familyMedicine: "Family medicine"
        case .neurology: "Neurology"
        case .emergency: "Emergency medicine"
        case .clinicalPsychology: "Clinical psychology"
        case .dermatology: "Dermatology"
        }
    }

    var examples: String {
        switch self {
        case .internalMedicine: "Chest pain, dyspnea, sepsis"
        case .surgery: "Abdominal pain, post-op fever"
        case .pediatrics: "Febrile infant, wheeze, rash"
        case .obgyn: "Bleeding in pregnancy, pelvic pain"
        case .psychiatry: "Low mood, psychosis, withdrawal"
        case .familyMedicine: "Cough, back pain, check-ups"
        case .neurology: "Headache, weakness, seizures"
        case .emergency: "Undifferentiated, time-critical"
        case .clinicalPsychology: "Intake, assessment, therapy plan"
        case .dermatology: "Rash, lesions, itch"
        }
    }
}
