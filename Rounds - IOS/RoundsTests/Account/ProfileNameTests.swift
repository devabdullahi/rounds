import Foundation
import Testing
@testable import Rounds

/// What a typed profile name becomes when saved.
struct ProfileNameTests {
    @Test(arguments: [("Sam", "Sam"), ("  Sam   Rivera ", "Sam Rivera"), ("Sam\nRivera", "Sam Rivera")])
    func namesAreTidied(typed: String, saved: String) {
        #expect(ProfileName.clean(typed) == saved)
    }

    @Test func emptyNamesAreNotSaved() {
        #expect(ProfileName.clean("") == nil)
        #expect(ProfileName.clean("   \n ") == nil)
    }

    @Test func longNamesAreCapped() {
        #expect(ProfileName.clean(String(repeating: "a", count: 80))?.count == ProfileName.maxLength)
    }
}
