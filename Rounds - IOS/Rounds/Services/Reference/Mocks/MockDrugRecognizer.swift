import Foundation

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
