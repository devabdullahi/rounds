import Foundation

struct MockDifferentialChecker: DifferentialChecking {
    func differential(for findings: [String]) async throws -> [RankedDiagnosis] {
        try await simulatedLatency()
        let all = ReferenceMatching.normalize(findings.joined(separator: " "))
        guard all.contains("chest") else { return [] }
        return [
            RankedDiagnosis(name: "STEMI", probability: 0.62),
            RankedDiagnosis(name: "Unstable angina", probability: 0.14),
            RankedDiagnosis(name: "Pulmonary embolism", probability: 0.08),
            RankedDiagnosis(name: "Aortic dissection", probability: 0.05),
            RankedDiagnosis(name: "Acute pericarditis", probability: 0.04),
        ]
    }
}
