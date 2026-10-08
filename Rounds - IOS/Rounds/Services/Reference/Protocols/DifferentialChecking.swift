import Foundation

protocol DifferentialChecking: Sendable {
    /// Ranked diagnoses for a set of findings, to sanity-check a drafted case's answer key.
    func differential(for findings: [String]) async throws -> [RankedDiagnosis]
}
