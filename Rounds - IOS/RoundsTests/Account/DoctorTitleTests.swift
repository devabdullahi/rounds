import Testing
@testable import Rounds

/// The welcome badge's name: "Dr." and the last name, or the only name; nothing without a name.
struct DoctorTitleTests {
    @Test(arguments: [("Sam Rivera", "Dr. Rivera"), ("Ana Maria Lopez", "Dr. Lopez"), ("Sam", "Dr. Sam"), ("  Jo  Kim ", "Dr. Kim")])
    func titleUsesTheLastName(full: String, title: String) {
        #expect(DoctorTitle.from(fullName: full) == title)
    }

    @Test func noNameNoTitle() {
        #expect(DoctorTitle.from(fullName: nil) == nil)
        #expect(DoctorTitle.from(fullName: "   ") == nil)
        #expect(DoctorTitle.firstName(of: "Sam Rivera") == "Sam")
    }
}
