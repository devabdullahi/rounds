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
