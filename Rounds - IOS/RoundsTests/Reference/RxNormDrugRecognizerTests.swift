import Testing
@testable import Rounds

@Suite("RxNorm drug recognition")
struct RxNormDrugRecognizerTests {
    private let names: Set<String> = ["aspirin", "metoprolol", "sodium", "sodium chloride", "lipitor", "water", "heparin", "iron"]

    @Test(arguments: [
        ("Give aspirin and metoprolol", ["aspirin", "metoprolol"]),
        ("Start ASA 325 mg and NTG", ["aspirin", "nitroglycerin"]),
        ("Bolus of normal saline", ["sodium chloride"]),
        ("IV sodium chloride", ["sodium chloride"]),
        ("Continue Lipitor", ["lipitor"]),
        ("Encourage water and rest", []),
        ("Admit to telemetry", []),
    ])
    func findsDrugsInReadingOrder(text: String, expected: [String]) {
        #expect(RxNormDrugRecognizer.find(in: text, names: names).map(\.name) == expected)
    }

    @Test func displayCapitalizes() {
        #expect(RxNormDrugRecognizer.display("metoprolol") == "Metoprolol")
    }
}
