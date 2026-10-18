import Foundation
import Testing
@testable import Rounds

@Suite("Past try decoding")
struct PastTryDecodingTests {
    private let tests = [Investigation(id: "cbc", name: "CBC", detail: "", cost: 0),
                         Investigation(id: "hsv_pcr", name: "HSV PCR", detail: "", cost: 0)]
    private let exam = [ExamManeuver(id: "oral", title: "Oral cavity")]

    @Test func namesWhatWasOrderedAndExaminedInOrder() throws {
        let json = """
        [{"id": "a1", "submitted_at": "2026-10-05T23:12:01.123456+00:00", "score": 41,
          "grade": {"verdict": "Missed diagnosis", "diagnosis_correct": false, "diagnosis": "Recurrent aphthous stomatitis",
                    "feedback": [{"tone": "miss", "title": "Missed", "detail": "Look again.", "covers_miss": null}],
                    "missed_red_flags": [{"flag": "Bowel symptoms", "why": "Could be IBD."}], "score": 41},
          "diagnosis": "Oral herpes", "differential": ["Hand-foot-mouth disease"], "plan": "Acyclovir.",
          "ordered_tests": [{"id": "hsv_pcr", "at": "x"}, {"id": "gone", "at": "x"}, {"id": "cbc", "at": "x"}],
          "examined": ["oral"], "exam_mode": true}]
        """
        let tries = try LiveCaseService.decodePastTries(from: Data(json.utf8), tests: tests, exam: exam)
        let t = try #require(tries.first)
        #expect(t.yourDiagnosis == "Oral herpes")
        #expect(t.actualDiagnosis == "Recurrent aphthous stomatitis")
        #expect(t.diagnosisCorrect == false)
        #expect(t.testsOrdered == ["HSV PCR", "CBC"])
        #expect(t.examDone == ["Oral cavity"])
        #expect(t.differential == ["Hand-foot-mouth disease"])
        #expect(t.missedRedFlags.map(\.flag) == ["Bowel symptoms"])
        #expect(t.examMode)
    }

    @Test func skipsAttemptsWithoutAGradeAndToleratesMissingFields() throws {
        let json = """
        [{"id": "a2", "submitted_at": "2026-10-05T23:12:01+00:00", "score": null, "grade": null},
         {"id": "a3", "submitted_at": "2026-10-06T10:00:00+00:00", "score": 90,
          "grade": {"verdict": "Textbook workup", "diagnosis_correct": true, "diagnosis": "Asthma", "feedback": [], "missed_red_flags": []},
          "diagnosis": null, "differential": null, "plan": null, "ordered_tests": null, "examined": null, "exam_mode": null}]
        """
        let tries = try LiveCaseService.decodePastTries(from: Data(json.utf8), tests: tests, exam: exam)
        #expect(tries.map(\.id) == ["a3"])
        #expect(tries.first?.yourDiagnosis == "")
        #expect(tries.first?.testsOrdered == [])
    }
}
