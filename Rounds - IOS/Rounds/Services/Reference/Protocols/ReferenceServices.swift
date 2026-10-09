import Foundation

// Contracts for outside medical reference data. Screens and models depend on these protocols,
// never on a specific provider, so mock and live versions swap in one place (App/ReferenceEnvironment).
//
// | Protocol            | Live source                                   | Used by                 |
// |---------------------|-----------------------------------------------|-------------------------|
// | ConditionSearching  | NLM Clinical Table Search                     | Diagnosis autocomplete  |
// | DrugRecognizing     | NLM RxNorm (RxNav names + rxcui lookup)       | Plan: recognised drugs  |
// | HealthTopicLinking  | MedlinePlus health-topic search (NLM)         | Debrief: "Learn more"   |
//
// Disease facts and the differential review arrive with the grade, built server-side from the
// case's condition profile (`Grade.about` / `Grade.differential`); synthetic patients are Synthea
// backgrounds the backend uses when generating cases. The app needs no clients for those.
// Live clients cache results (NLM asks for ≤ 20 requests/s per IP and 12–24 h caching).

/// Everything reference-related the app needs, bundled so it's injected once.
struct ReferenceServices: Sendable {
    var conditions: any ConditionSearching
    var drugs: any DrugRecognizing
    var topics: any HealthTopicLinking

    /// What the app runs on: every service is live.
    static let live = ReferenceServices(
        conditions: ClinicalTablesConditionSearch(),
        drugs: RxNormDrugRecognizer(),
        topics: MedlinePlusHealthTopics()
    )

    /// Offline, deterministic data, for previews and tests only.
    static let mock = ReferenceServices(
        conditions: MockConditionSearch(),
        drugs: MockDrugRecognizer(),
        topics: MockHealthTopics()
    )
}
