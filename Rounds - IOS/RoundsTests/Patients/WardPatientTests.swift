import Testing
@testable import Rounds

@Suite("Ward patient short complaint")
struct WardPatientTests {
    private func patient(complaint: String) -> WardPatient {
        WardPatient(id: "X1", quote: "My feet feel stuck.", meta: "M · 65", rotation: nil, system: nil,
                    hr: nil, bp: nil, spo2: nil, status: .resume, complaint: complaint)
    }

    @Test("drops the age and sex the meta line already shows", arguments: [
        ("65-year-old man with 6 months of trouble walking.", "6 months of trouble walking"),
        ("3-month-old boy, fast breathing since birth", "Fast breathing since birth"),
        ("21 year old male presenting with blurry vision in one eye", "Blurry vision in one eye"),
        ("Chest tightness on stairs for 2 weeks", "Chest tightness on stairs for 2 weeks"),
    ])
    func strips(complaint: String, expected: String) {
        #expect(patient(complaint: complaint).shortComplaint == expected)
    }

    @Test func fallsBackToTheQuote() {
        #expect(patient(complaint: "").shortComplaint == "\u{201C}My feet feel stuck.\u{201D}")
    }
}
