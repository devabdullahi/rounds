import Foundation

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
