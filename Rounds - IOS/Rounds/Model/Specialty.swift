import Foundation

/// The residency specialty a student is aiming for, shown on their profile. Only a label for now:
/// it doesn't change which patients they get (that's `StudyFocus`).
enum Specialty: String, CaseIterable, Identifiable, Sendable {
    case undecided
    case anesthesiology, dermatology, emergencyMedicine, familyMedicine, internalMedicine
    case neurology, neurosurgery, obgyn, ophthalmology, orthopedicSurgery, otolaryngology
    case pathology, pediatrics, physicalMedicine, plasticSurgery, psychiatry
    case radiationOncology, radiology, generalSurgery, urology

    var id: String { rawValue }

    var label: String {
        switch self {
        case .undecided: "Undecided"
        case .anesthesiology: "Anesthesiology"
        case .dermatology: "Dermatology"
        case .emergencyMedicine: "Emergency medicine"
        case .familyMedicine: "Family medicine"
        case .internalMedicine: "Internal medicine"
        case .neurology: "Neurology"
        case .neurosurgery: "Neurosurgery"
        case .obgyn: "OB/GYN"
        case .ophthalmology: "Ophthalmology"
        case .orthopedicSurgery: "Orthopedic surgery"
        case .otolaryngology: "ENT"
        case .pathology: "Pathology"
        case .pediatrics: "Pediatrics"
        case .physicalMedicine: "PM&R"
        case .plasticSurgery: "Plastic surgery"
        case .psychiatry: "Psychiatry"
        case .radiationOncology: "Radiation oncology"
        case .radiology: "Radiology"
        case .generalSurgery: "General surgery"
        case .urology: "Urology"
        }
    }

    /// Undecided first, then A to Z by label.
    static var ordered: [Specialty] {
        [.undecided] + allCases.filter { $0 != .undecided }.sorted { $0.label < $1.label }
    }
}
