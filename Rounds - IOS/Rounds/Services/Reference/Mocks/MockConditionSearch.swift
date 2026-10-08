import Foundation

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
