import Foundation

// Mock reference data: offline, deterministic, small. Codes and IDs are real-shaped (ICD-10-CM,
// RxNorm RXCUI, MedlinePlus URLs) so the live versions can replace these without changing callers,
// but this is sample data, not an authoritative source. Each mock waits briefly like a network call.

private func simulatedLatency() async throws {
    try await Task.sleep(for: .milliseconds(150))
}

// MARK: - Conditions (stands in for NLM Clinical Table Search, ICD-10-CM)

struct MockConditionSearch: ConditionSearching {
    static let catalog: [ConditionMatch] = [
        ConditionMatch(code: "I21.19", name: "STEMI of inferior wall",
                       synonyms: ["Inferior STEMI", "Inferior myocardial infarction", "Heart attack", "ST elevation myocardial infarction"]),
        ConditionMatch(code: "I21.3", name: "STEMI of unspecified site", synonyms: ["STEMI", "ST elevation myocardial infarction"]),
        ConditionMatch(code: "I21.4", name: "Non-ST elevation myocardial infarction", synonyms: ["NSTEMI"]),
        ConditionMatch(code: "I20.0", name: "Unstable angina", synonyms: ["Acute coronary syndrome", "ACS"]),
        ConditionMatch(code: "I71.00", name: "Aortic dissection", synonyms: ["Dissection of aorta"]),
        ConditionMatch(code: "I26.99", name: "Pulmonary embolism", synonyms: ["PE"]),
        ConditionMatch(code: "I30.9", name: "Acute pericarditis", synonyms: ["Pericarditis"]),
        ConditionMatch(code: "K21.9", name: "Gastroesophageal reflux disease", synonyms: ["GERD", "Acid reflux"]),
        ConditionMatch(code: "F41.0", name: "Panic disorder", synonyms: ["Panic attack"]),
        ConditionMatch(code: "J93.9", name: "Pneumothorax", synonyms: ["Collapsed lung"]),
        ConditionMatch(code: "J18.9", name: "Pneumonia", synonyms: ["Community-acquired pneumonia", "CAP"]),
        ConditionMatch(code: "M94.0", name: "Costochondritis", synonyms: ["Tietze syndrome", "Chest wall pain"]),
        ConditionMatch(code: "I48.91", name: "Atrial fibrillation", synonyms: ["AFib", "AF"]),
        ConditionMatch(code: "I50.9", name: "Heart failure", synonyms: ["CHF", "Congestive heart failure"]),
        ConditionMatch(code: "I60.9", name: "Subarachnoid hemorrhage", synonyms: ["Subarachnoid bleed", "SAH"]),
        ConditionMatch(code: "G43.909", name: "Migraine", synonyms: ["Migraine headache"]),
        ConditionMatch(code: "G03.9", name: "Meningitis", synonyms: []),
        ConditionMatch(code: "G44.209", name: "Tension-type headache", synonyms: ["Tension headache"]),
        ConditionMatch(code: "K35.80", name: "Acute appendicitis", synonyms: ["Appendicitis"]),
        ConditionMatch(code: "K81.0", name: "Acute cholecystitis", synonyms: ["Cholecystitis", "Gallbladder inflammation"]),
        ConditionMatch(code: "N20.0", name: "Kidney stone", synonyms: ["Nephrolithiasis", "Renal calculus"]),
        ConditionMatch(code: "J45.901", name: "Asthma exacerbation", synonyms: ["Asthma attack"]),
    ]

    func search(_ text: String, limit: Int) async throws -> [ConditionMatch] {
        try await simulatedLatency()
        return ReferenceMatching.rankConditions(text, in: Self.catalog, limit: limit)
    }
}

// MARK: - Drugs (stands in for NLM RxNorm)

struct MockDrugRecognizer: DrugRecognizing {
    static let catalog: [(rxcui: String, name: String, aliases: [String])] = [
        ("1191", "Aspirin", ["ASA", "acetylsalicylic acid"]),
        ("5224", "Heparin", ["UFH", "unfractionated heparin"]),
        ("67108", "Enoxaparin", ["Lovenox"]),
        ("4917", "Nitroglycerin", ["nitro", "GTN", "NTG"]),
        ("32968", "Clopidogrel", ["Plavix"]),
        ("1116632", "Ticagrelor", ["Brilinta"]),
        ("83367", "Atorvastatin", ["Lipitor"]),
        ("6918", "Metoprolol", ["Lopressor"]),
        ("7052", "Morphine", []),
        ("8410", "Alteplase", ["tPA"]),
        ("7806", "Oxygen", ["O2"]),
    ]

    func recognize(in text: String) async throws -> [DrugMatch] {
        try await simulatedLatency()
        return ReferenceMatching.recognizeDrugs(in: text, catalog: Self.catalog)
    }
}

// MARK: - Health topics (stands in for MedlinePlus Connect)

struct MockHealthTopics: HealthTopicLinking {
    /// Keyword in the diagnosis → page. First keyword found wins.
    private static let pages: [(keywords: [String], topic: HealthTopic)] = [
        (["stemi", "myocardial infarction", "heart attack", "acute coronary", "angina"],
         topic("Heart Attack", "What happens in a heart attack, warning signs, and treatment.", "heartattack")),
        (["pulmonary embolism"], topic("Pulmonary Embolism", "Blood clots in the lungs: causes, symptoms and treatment.", "pulmonaryembolism")),
        (["appendicitis"], topic("Appendicitis", "Inflammation of the appendix and why it's an emergency.", "appendicitis")),
        (["migraine"], topic("Migraine", "Migraine symptoms, triggers and treatment.", "migraine")),
        (["meningitis"], topic("Meningitis", "Infection of the membranes around the brain and spinal cord.", "meningitis")),
        (["reflux", "gerd"], topic("GERD", "Acid reflux, heartburn and how it's treated.", "gerd")),
        (["pneumonia"], topic("Pneumonia", "Lung infection: symptoms, causes and care.", "pneumonia")),
        (["asthma"], topic("Asthma", "Airway inflammation, attacks and long-term control.", "asthma")),
        (["atrial fibrillation", "afib"], topic("Atrial Fibrillation", "An irregular heartbeat and stroke prevention.", "atrialfibrillation")),
        (["heart failure"], topic("Heart Failure", "When the heart can't pump enough blood: symptoms and treatment.", "heartfailure")),
        (["panic"], topic("Panic Disorder", "Panic attacks and how they're treated.", "panicdisorder")),
    ]

    private static func topic(_ title: String, _ summary: String, _ slug: String) -> HealthTopic {
        HealthTopic(title: title, summary: summary, url: URL(string: "https://medlineplus.gov/\(slug).html")!)
    }

    func topics(for diagnosis: String) async throws -> [HealthTopic] {
        try await simulatedLatency()
        let d = ReferenceMatching.normalize(diagnosis)
        return Self.pages.first { $0.keywords.contains { d.contains($0) } }.map { [$0.topic] } ?? []
    }
}

// MARK: - Authoring helpers (stand in for Disease Ontology / Wikidata, Synthea, EndlessMedical)

struct MockDiseaseFacts: DiseaseFactProviding {
    private static let facts: [String: DiseaseFacts] = [
        "I21.19": DiseaseFacts(conditionCode: "I21.19",
                               symptoms: ["Central chest pressure", "Radiation to left arm or jaw", "Sweating", "Nausea", "Shortness of breath"],
                               riskFactors: ["Smoking", "Hypertension", "Diabetes", "Family history of early heart disease", "High cholesterol"],
                               redFlags: ["Tearing pain to the back (dissection)", "Unequal arm blood pressures", "Cocaine use"]),
        "I60.9": DiseaseFacts(conditionCode: "I60.9",
                              symptoms: ["Sudden severe headache", "Neck stiffness", "Vomiting", "Light sensitivity"],
                              riskFactors: ["Hypertension", "Smoking", "Family history of aneurysm"],
                              redFlags: ["Thunderclap onset", "Reduced consciousness", "New neurological deficit"]),
        "K35.80": DiseaseFacts(conditionCode: "K35.80",
                               symptoms: ["Pain starting near the navel, moving to the right lower abdomen", "Loss of appetite", "Low fever", "Nausea"],
                               riskFactors: ["Age 10–30"],
                               redFlags: ["Rigid abdomen (perforation)", "Pregnancy test not done in a female patient"]),
    ]

    func facts(forCode code: String) async throws -> DiseaseFacts? {
        try await simulatedLatency()
        return Self.facts[code]
    }
}

struct MockSyntheticPatients: SyntheticPatientMaking {
    func patient(forCode code: String) async throws -> SyntheticPatient {
        try await simulatedLatency()
        switch code {
        case "I21.19":
            return SyntheticPatient(age: 54, sex: "M",
                                    vitals: ["HR": "104", "BP": "148/92", "SpO₂": "95%", "RR": "20", "Temp": "98.4 °F"],
                                    labs: ["Troponin (hs)": "312 ng/L", "Hgb": "14.2 g/dL", "K": "4.1 mmol/L", "Creatinine": "1.0 mg/dL"])
        default:
            return SyntheticPatient(age: 40, sex: "F",
                                    vitals: ["HR": "88", "BP": "124/78", "SpO₂": "98%", "RR": "16", "Temp": "98.6 °F"],
                                    labs: ["Hgb": "13.1 g/dL", "WBC": "7.2 ×10³/µL", "Creatinine": "0.8 mg/dL"])
        }
    }
}

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
