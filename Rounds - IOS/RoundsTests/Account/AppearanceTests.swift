import Testing
@testable import Rounds

/// The appearance a student gets before choosing one, and the stored choices that must survive.
struct AppearanceTests {
    @Test func neverPickedOpensLight() {
        #expect(Appearance.defaultChoice == .light)
    }

    @Test(arguments: [(0, Appearance.system), (1, .light), (2, .dark)])
    func storedChoicesKeepTheirRawValues(raw: Int, choice: Appearance) {
        #expect(Appearance(rawValue: raw) == choice)
    }
}
