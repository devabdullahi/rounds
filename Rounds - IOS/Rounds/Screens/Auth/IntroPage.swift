import Foundation

/// The carousel a new student swipes through right after creating an account: four intro pages,
/// then "What are you studying for?". One carousel, so every page slides in the same way.
enum IntroPage: Int, CaseIterable {
    case patients, graded, promise, examReady, studyGoal

    var headline: String {
        switch self {
        case .patients: "Patients Who\nTalk Back"
        case .graded: "Graded On\nEvery Move"
        case .promise: "Think Like\na Doctor"
        case .examReady: "Walk Into Your\nExam Ready"
        case .studyGoal: "What Are You\nStudying For?"
        }
    }
}
