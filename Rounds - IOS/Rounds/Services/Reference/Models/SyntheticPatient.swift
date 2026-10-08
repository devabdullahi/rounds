import Foundation

/// A believable synthetic patient for a case draft (Synthea-style). Authoring only.
struct SyntheticPatient: Hashable, Sendable {
    let age: Int
    let sex: String
    let vitals: [String: String]    // "HR": "104"
    let labs: [String: String]      // "Troponin (hs)": "312 ng/L"
}
