import Foundation

// Domain types returned by the reference services. They describe medicine, not wire formats:
// each live service (NLM, MedlinePlus, Disease Ontology…) maps its own JSON into these.

/// A condition from a standard list, e.g. "STEMI, inferior wall" with its ICD-10-CM code.
struct ConditionMatch: Identifiable, Hashable, Sendable {
    let code: String            // ICD-10-CM
    let name: String
    let synonyms: [String]
    var id: String { code }
}

/// A drug recognised in free text, normalised to its RxNorm concept.
struct DrugMatch: Identifiable, Hashable, Sendable {
    let rxcui: String
    let name: String            // normalised name, e.g. "Aspirin"
    let matchedText: String     // what the student actually typed, e.g. "ASA"
    var id: String { rxcui }
}

/// A plain-language page to read after a case.
struct HealthTopic: Identifiable, Hashable, Sendable {
    let title: String
    let summary: String
    let url: URL
    var id: URL { url }
}

/// Background facts for drafting a case. Authoring only: never shown to students as-is.
struct DiseaseFacts: Hashable, Sendable {
    let conditionCode: String
    let symptoms: [String]
    let riskFactors: [String]
    let redFlags: [String]
}

/// A believable synthetic patient for a case draft (Synthea-style). Authoring only.
struct SyntheticPatient: Hashable, Sendable {
    let age: Int
    let sex: String
    let vitals: [String: String]    // "HR": "104"
    let labs: [String: String]      // "Troponin (hs)": "312 ng/L"
}

/// One entry in a ranked differential from a diagnosis engine. Authoring and QA only.
struct RankedDiagnosis: Hashable, Sendable {
    let name: String
    let probability: Double         // 0…1
}
