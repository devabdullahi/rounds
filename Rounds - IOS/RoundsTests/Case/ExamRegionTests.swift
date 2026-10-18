import Testing
@testable import Rounds

@Suite("Exam region")
struct ExamRegionTests {
    @Test(arguments: [
        ("Observe and count the respiratory rate for one full minute", ExamRegion.vitals),
        ("Measure blood pressure", .vitals),
        ("Observe the nose during breathing", .headNeck),
        ("Auscultate the chest", .chest),
        ("Auscultate both lung fields", .chest),
        ("Inspect and palpate the abdomen", .abdomen),
        ("Check capillary refill", .limbsSkin),
        ("Test deep tendon reflexes", .neuro),
        ("General appearance", .general),
    ])
    func titlesFindTheirRegion(title: String, region: ExamRegion) {
        #expect(ExamRegion.of(title) == region)
    }

    @Test func groupsFollowExamOrderAndKeepTheCasesOrderWithin() {
        let exam = [ExamManeuver(id: "abd", title: "Palpate abdomen"), ExamManeuver(id: "lung", title: "Auscultate lungs"),
                    ExamManeuver(id: "rr", title: "Respiratory rate"), ExamManeuver(id: "heart", title: "Listen to the heart")]
        let groups = ExamRegion.grouped(exam)
        #expect(groups.map(\.region) == [.vitals, .chest, .abdomen])
        #expect(groups[1].maneuvers.map(\.id) == ["lung", "heart"])
    }

    @Test(arguments: [(0, "infant"), (1, "1"), (54, "54")])
    func agesUnderOneReadAsInfant(years: Int, label: String) {
        #expect(PatientAge.label(years) == label)
    }
}
