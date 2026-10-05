import Testing
@testable import Rounds

@Suite("Study focus selection")
struct FocusSelectionTests {
    @Test func emptyMeansMix() {
        let s = FocusSelection(stored: "")
        #expect(s.isMix)
        #expect(s.label == "Mixed cases")
        #expect(s.matches(rotation: .surgery, system: .gastrointestinal))
    }

    @Test func readsOlderSingleValue() {
        let s = FocusSelection(stored: "rotation:internalMedicine")
        #expect(s.items == [.rotation(.internalMedicine)])
    }

    @Test func storedValueRoundTrips() {
        let s = FocusSelection([.rotation(.surgery), .system(.nervous)])
        #expect(FocusSelection(stored: s.stored) == s)
    }

    @Test func ignoresDuplicatesAndGarbage() {
        let s = FocusSelection(stored: "rotation:surgery,rotation:surgery,banana,system:nope")
        #expect(s.items == [.rotation(.surgery)])
    }

    @Test func toggleAddsThenRemoves() {
        var s = FocusSelection()
        s.toggle(.rotation(.pediatrics))
        #expect(s.contains(.rotation(.pediatrics)))
        s.toggle(.rotation(.pediatrics))
        #expect(s.isMix)
    }

    @Test func matchesAnyPick() {
        let s = FocusSelection([.rotation(.neurology), .system(.cardiovascular)])
        #expect(s.matches(rotation: .internalMedicine, system: .cardiovascular))
        #expect(s.matches(rotation: .neurology, system: .nervous))
        #expect(!s.matches(rotation: .surgery, system: .gastrointestinal))
    }

    @Test(arguments: [
        ([StudyFocus.rotation(.surgery)], "Surgery"),
        ([.rotation(.surgery), .rotation(.neurology)], "Surgery + Neurology"),
        ([.rotation(.internalMedicine), .rotation(.neurology)], "Internal medicine +1"),
        ([.rotation(.surgery), .rotation(.neurology), .rotation(.psychiatry)], "Surgery +2"),
    ])
    func labels(items: [StudyFocus], expected: String) {
        #expect(FocusSelection(items).label == expected)
    }
}
