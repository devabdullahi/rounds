import Foundation

protocol SyntheticPatientMaking: Sendable {
    func patient(forCode code: String) async throws -> SyntheticPatient
}
