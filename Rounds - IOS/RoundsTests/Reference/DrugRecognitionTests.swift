import Testing
@testable import Rounds

@Suite("Drug recognition")
struct DrugRecognitionTests {
    let catalog = MockDrugRecognizer.catalog

    func names(_ text: String) -> [String] {
        ReferenceMatching.recognizeDrugs(in: text, catalog: catalog).map(\.name)
    }

    @Test func findsDrugsInOrderOfAppearance() {
        #expect(names("Give heparin, then aspirin 325 mg") == ["Heparin", "Aspirin"])
    }

    @Test(arguments: [
        ("ASA 325 chewed", "Aspirin"),
        ("start nitro SL", "Nitroglycerin"),
        ("unfractionated heparin bolus", "Heparin"),
        ("O2 if sats < 90", "Oxygen"),
    ])
    func recognisesAliases(text: String, expected: String) {
        #expect(names(text) == [expected])
    }

    @Test func matchesWholeWordsOnly() {
        // "asa" inside "nasal" and "o2" inside "co2" must not count.
        #expect(names("nasal cannula, check CO2").isEmpty)
    }

    @Test func listsEachDrugOnce() {
        #expect(names("aspirin now, aspirin daily") == ["Aspirin"])
    }
}
