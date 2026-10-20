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

    @Test(arguments: ["office", "Clinic", "inpatient"])
    func unknownStoredValueReadsAsAny(stored: String) {
        #expect(CareSetting(stored: stored) == .any)
    }
}
