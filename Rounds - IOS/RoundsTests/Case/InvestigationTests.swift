import Testing
@testable import Rounds

@Suite("Investigation")
struct InvestigationTests {
    @Test(arguments: [
        ("Bloods · 4 min", "Bloods"),
        ("Imaging · 20 mins", "Imaging"),
        ("Questionnaire · 3 min", "Questionnaire"),
        ("Bedside · ~2 min · Point of care", "Bedside · Point of care"),
        ("12-lead ECG", "12-lead ECG"),
        ("4 min", ""),
    ])
    func waitTimesAreLeftOff(detail: String, kind: String) {
        #expect(Investigation.withoutDuration(detail) == kind)
    }
}
