import Foundation

/// Every onboarding step, in order: four intro pages, the study goal, the focus picker, making the
/// account (only when onboarding began signed out) and the promise. They're pages of one carousel
/// (`OnboardingView`), so every step slides the same way.
enum OnboardingPage: Int, CaseIterable {
    case patients, graded, promise, examReady, studyGoal, focus, account, pledge

    /// The big headline under the hero art; the focus picker sets its own title.
    var headline: String? {
        switch self {
        case .patients: "Patients Who\nTalk Back"
        case .graded: "Graded On\nEvery Move"
        case .promise: "Think Like\na Doctor"
        case .examReady: "Walk Into Your\nExam Ready"
        case .studyGoal: "What Are You\nStudying For?"
        case .account: "Save Your\nProgress"
        case .focus, .pledge: nil
        }
    }
}
