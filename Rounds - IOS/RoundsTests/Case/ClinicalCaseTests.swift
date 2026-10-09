import Testing
@testable import Rounds

struct ClinicalCaseTests {
    @Test("Initials skip nicknames and punctuation", arguments: [
        ("Margaret \"Maggie\" Ellison", "ME"),
        ("Walter Brennan", "WB"),
        ("Edna May Whitfield", "EW"),
        ("Cher", "C"),
    ])
    func initials(name: String, expected: String) {
        #expect(patient(named: name).initials == expected)
    }

    @Test("First name skips a leading nickname", arguments: [
        ("Margaret \"Maggie\" Ellison", "Margaret"),
        ("\"Bud\" Walter Brennan", "Walter"),
        ("Cher", "Cher"),
        ("", ""),
    ])
    func firstName(name: String, expected: String) {
        #expect(patient(named: name).firstName == expected)
    }

    private func patient(named name: String) -> ClinicalCase {
        ClinicalCase(bed: "X1", name: name, age: 40, sex: "F", setting: "", quote: "", demeanor: "", complaint: "",
                     vitals: [], task: "", minutes: 10, budget: 100, suggestedQuestions: [], exam: [], tests: [],
                     clerkship: nil, system: nil, keyHistoryTotal: 0)
    }
}
