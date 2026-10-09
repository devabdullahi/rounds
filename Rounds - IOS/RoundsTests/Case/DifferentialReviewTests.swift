import Testing
@testable import Rounds

/// How the debrief shortens a long differential, and phrases the student's extra guesses.
struct DifferentialReviewTests {
    private func item(_ name: String, dangerous: Bool = false) -> DifferentialReview {
        DifferentialReview(name: name, mustNotMiss: dangerous, why: "", tellApart: [], inYours: false)
    }

    @Test func collapsedKeepsFirstItemsAndAnyLaterMustNotMiss() {
        let items = [item("A"), item("B"), item("C"), item("D"), item("E", dangerous: true)]
        #expect(DifferentialReview.collapsed(items, limit: 3).map(\.name) == ["A", "B", "C", "E"])
    }

    @Test func collapsedShortListIsUnchanged() {
        let items = [item("A"), item("B")]
        #expect(DifferentialReview.collapsed(items, limit: 3).map(\.name) == ["A", "B"])
    }

    @Test(arguments: [
        ([], nil),
        (["  "], nil),
        (["Scurvy"], "Also on your list: Scurvy. Not a usual consideration for this case."),
        (["Scurvy", "Measles"], "Also on your list: Scurvy, Measles. Not usual considerations for this case."),
    ] as [([String], String?)])
    func extrasNote(extras: [String], expected: String?) {
        #expect(DifferentialReview.extrasNote(extras) == expected)
    }
}
