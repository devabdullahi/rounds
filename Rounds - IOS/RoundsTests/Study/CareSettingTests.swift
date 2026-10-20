import Testing
@testable import Rounds

struct CareSettingTests {
    @Test(arguments: CareSetting.allCases)
    func storedValueRoundTrips(setting: CareSetting) {
        #expect(CareSetting(stored: setting.rawValue) == setting)
    }

    /// The raw values are what the server accepts: "", "clinic", "hospital".
    @Test func rawValuesMatchTheServer() {
        #expect(CareSetting.allCases.map(\.rawValue) == ["", "clinic", "hospital"])
    }

    /// OSCEs are outpatient, so an OSCE student starts in clinic cases; everyone else in any setting.
    @Test(arguments: StudyGoal.allCases)
    func onboardingGoalPicksTheStartingSetting(goal: StudyGoal) {
        #expect(goal.careSetting == (goal == .osce ? .clinic : .any))
    }

    @Test(arguments: ["office", "Clinic", "inpatient"])
    func unknownStoredValueReadsAsAny(stored: String) {
        #expect(CareSetting(stored: stored) == .any)
    }
}
