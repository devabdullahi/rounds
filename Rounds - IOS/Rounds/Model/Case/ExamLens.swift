import Foundation

/// The case taught the way the student's exam asks about it ("For Step 2 CK: next best steps"),
/// shown in the debrief. Built by the server from the condition's profile.
struct ExamLens: Equatable {
    let title: String
    let points: [String]
}
