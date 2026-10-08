import Foundation
import Testing
@testable import Rounds

@Suite("Focus progress")
struct FocusProgressTests {
    private func graded(_ id: String, _ rotation: Clerkship?, _ system: OrganSystem?, caseID: String? = nil) -> GradedCase {
        GradedCase(id: id, submittedAt: .now, score: 80, diagnosisCorrect: true, missedRedFlags: 0,
                   clerkship: rotation, system: system, breakdown: [:], caseID: caseID)
    }

    private let counts = ["rotation:surgery": 141, "rotation:pediatrics": 222]

    @Test func countsDifferentPatientsInTheFocus() {
        let cases = [graded("1", .surgery, .gastrointestinal, caseID: "a"),
                     graded("2", .surgery, .gastrointestinal, caseID: "a"),   // a retry
                     graded("3", .surgery, .cardiovascular, caseID: "b"),
                     graded("4", .pediatrics, .respiratory, caseID: "c")]
        let progress = FocusProgress.of(cases, in: FocusSelection([.rotation(.surgery)]), counts: counts)
        #expect(progress == FocusProgress(done: 2, total: 141))
    }

    @Test func aMixCountsEverything() {
        let cases = [graded("1", .surgery, .gastrointestinal), graded("2", nil, nil)]
        #expect(FocusProgress.of(cases, in: FocusSelection(), counts: counts) == FocusProgress(done: 2, total: 363))
    }

    @Test func unknownBeforeCountsLoad() {
        #expect(FocusProgress.of([], in: FocusSelection(), counts: [:]) == nil)
    }
}
