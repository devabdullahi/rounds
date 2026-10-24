import Foundation
import Testing
@testable import Rounds

/// The grade JSON from `case-session` submit, mapped to `Grade`: the teaching fields when the
/// server sends them, and nothing (not a failure) on older grades that predate them.
struct GradeDecodingTests {
    private static let base = """
    "score": 86, "diagnosis_correct": true, "diagnosis": "Recurrent aphthous stomatitis",
    "verdict": "Right call.", "rating_delta": 12, "rating": 1312,
    "feedback": [{"tone": "good", "title": "Focused history", "detail": "Good timing questions."}],
    "missed_red_flags": []
    """

    private func decode(_ extra: String = "") throws -> Grade {
        let json = "{" + Self.base + (extra.isEmpty ? "" : ", " + extra) + "}"
        return try LiveCaseService.decodeGrade(from: Data(json.utf8))
    }

    @Test func olderGradeWithoutTeachingFieldsDecodesEmpty() throws {
        let g = try decode()
        #expect(g.score == 86)
        #expect(g.about == nil)
        #expect(g.differential.isEmpty)
        #expect(g.yourExtras.isEmpty)
    }

    @Test func breakdownMapsToScoreParts() throws {
        let g = try decode("""
        "breakdown": {"diagnosis": {"got": 35, "max": 35}, "red_flags": {"got": 5, "max": 10}, "unknown_part": {"got": 1, "max": 1}}
        """)
        #expect(g.breakdown[.diagnosis] == Points(got: 35, max: 35))
        #expect(g.breakdown[.redFlags] == Points(got: 5, max: 10))
        #expect(g.breakdown.count == 2)
        #expect(try decode().breakdown.isEmpty)
    }

    @Test func teachingFieldsMapToDomainTypes() throws {
        let g = try decode("""
        "about": {"summary_points": ["Benign, recurring ulcers."], "symptoms": ["Painful ulcers"], "risk_factors": ["Stress"]},
        "differential": [
          {"name": "Behçet disease", "must_not_miss": false, "why": "Recurrent oral ulcers.", "tell_apart": ["Genital ulcers"], "in_yours": true},
          {"name": "Oral squamous cell carcinoma", "must_not_miss": true, "why": "Non-healing sore.", "tell_apart": [], "in_yours": false}
        ],
        "your_extras": ["Scurvy"]
        """)
        let about = try #require(g.about)
        #expect(about.summaryPoints == ["Benign, recurring ulcers."])
        #expect(about.symptoms == ["Painful ulcers"])
        #expect(about.riskFactors == ["Stress"])
        #expect(g.differential.map(\.name) == ["Behçet disease", "Oral squamous cell carcinoma"])
        #expect(g.differential[0].inYours && !g.differential[0].mustNotMiss)
        #expect(g.differential[1].mustNotMiss && !g.differential[1].inYours)
        #expect(g.differential[0].tellApart == ["Genital ulcers"])
        #expect(g.yourExtras == ["Scurvy"])
    }

    @Test func emptyAboutIsTreatedAsAbsent() throws {
        let g = try decode(#""about": {"summary_points": [], "symptoms": [], "risk_factors": []}"#)
        #expect(g.about == nil)
    }

    @Test func differentialItemMissingOptionalKeysUsesSafeDefaults() throws {
        let g = try decode(#""differential": [{"name": "Hand-foot-mouth disease"}]"#)
        let item = try #require(g.differential.first)
        #expect(!item.mustNotMiss && !item.inYours)
        #expect(item.why.isEmpty && item.tellApart.isEmpty)
    }

    @Test func lensAndFocusNotesMapWhenSent() throws {
        let json = """
        {"score": 70, "diagnosis_correct": true, "diagnosis": "Acute cholecystitis", "verdict": "Right call.",
         "rating_delta": 5, "rating": 1210, "missed_red_flags": [],
         "feedback": [{"tone": "miss", "title": "History gap: onset", "detail": "You never asked about it.", "focus": true}],
         "lens": {"title": "For Step 2 CK: next best steps", "points": ["Ultrasound first"]}}
        """
        let g = try LiveCaseService.decodeGrade(from: Data(json.utf8))
        #expect(g.lens == ExamLens(title: "For Step 2 CK: next best steps", points: ["Ultrasound first"]))
        #expect(g.feedback.first?.isFocus == true)
    }

    @Test func olderGradesHaveNoLensAndNoFocusNotes() throws {
        let g = try decode()
        #expect(g.lens == nil)
        #expect(g.feedback.allSatisfy { !$0.isFocus })
    }
}
