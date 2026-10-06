import Foundation

// Contracts for outside medical reference data. Screens and models depend on these protocols,
// never on a specific provider, so mock and live versions swap in one place (App/ReferenceEnvironment).
//
// | Protocol                 | Live source (later)                    | Used by                 |
// |--------------------------|----------------------------------------|-------------------------|
// | ConditionSearching       | NLM Clinical Table Search (live)       | Diagnosis autocomplete  |
// | DrugRecognizing          | NLM RxNorm / RxNav                     | Plan: recognised drugs  |
// | HealthTopicLinking       | MedlinePlus Connect                    | Debrief: "Learn more"   |
// | DiseaseFactProviding     | Disease Ontology, Wikidata P780        | Case authoring only     |
// | SyntheticPatientMaking   | Synthea                                | Case authoring only     |
// | DifferentialChecking     | EndlessMedical (check terms first)     | Case QA only            |
//
// Condition search is live (ClinicalTablesConditionSearch); the rest are mock for now
// (MockReferenceServices). Live ones must cache results (NLM asks for ≤ 20 requests/s per IP and
// 12–24 h caching).

protocol ConditionSearching: Sendable {
    /// Best matches for what the student has typed so far, most relevant first.
    func search(_ text: String, limit: Int) async throws -> [ConditionMatch]
}

protocol DrugRecognizing: Sendable {
    /// Drugs mentioned anywhere in free text, in the order they appear.
    func recognize(in text: String) async throws -> [DrugMatch]
}

protocol HealthTopicLinking: Sendable {
    /// Patient-education pages for a diagnosis name or ICD-10 code.
    func topics(for diagnosis: String) async throws -> [HealthTopic]
}

protocol DiseaseFactProviding: Sendable {
    func facts(forCode code: String) async throws -> DiseaseFacts?
}

protocol SyntheticPatientMaking: Sendable {
    func patient(forCode code: String) async throws -> SyntheticPatient
}

protocol DifferentialChecking: Sendable {
    /// Ranked diagnoses for a set of findings, to sanity-check a drafted case's answer key.
    func differential(for findings: [String]) async throws -> [RankedDiagnosis]
}

/// Everything reference-related the app needs, bundled so it's injected once.
struct ReferenceServices: Sendable {
    var conditions: any ConditionSearching
    var drugs: any DrugRecognizing
    var topics: any HealthTopicLinking
    var diseaseFacts: any DiseaseFactProviding
    var syntheticPatients: any SyntheticPatientMaking
    var differentials: any DifferentialChecking

    /// What the app runs on: live clients where they exist, mock for the rest.
    static let live = ReferenceServices(
        conditions: ClinicalTablesConditionSearch(),
        drugs: MockDrugRecognizer(),
        topics: MockHealthTopics(),
        diseaseFacts: MockDiseaseFacts(),
        syntheticPatients: MockSyntheticPatients(),
        differentials: MockDifferentialChecker()
    )

    /// Offline, deterministic data, for previews and tests.
    static let mock = ReferenceServices(
        conditions: MockConditionSearch(),
        drugs: MockDrugRecognizer(),
        topics: MockHealthTopics(),
        diseaseFacts: MockDiseaseFacts(),
        syntheticPatients: MockSyntheticPatients(),
        differentials: MockDifferentialChecker()
    )
}
