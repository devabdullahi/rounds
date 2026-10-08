import Foundation

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
