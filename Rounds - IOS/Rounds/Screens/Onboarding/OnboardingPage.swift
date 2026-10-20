import Foundation

/// Every onboarding step, in order. Ordered for attention: one promise page, then one-tap questions
/// early (fast progress), a value page after each answer, the heavier focus picker mid-flow, the
/// answers read back as a plan, then the account (only when onboarding began signed out) and the
/// promise. They're pages of one carousel (`OnboardingView`), so every step slides the same way.
enum OnboardingPage: Int, CaseIterable {
    case patients, schoolYear, studyGoal, examReady, graded, focus, careSetting, redFlag, name, promise, missCards,
         plan, reminder, account, pledge

    /// The big headline under the hero art; the focus picker sets its own title.
    var headline: String? {
        switch self {
        case .patients: "Patients Who\nTalk Back"
        case .schoolYear: "What Year\nAre You In?"
        case .studyGoal: "What Are You\nStudying For?"
        case .examReady: "Walk Into Your\nExam Ready"
        case .graded: "Graded On\nEvery Move"
        case .careSetting: "Where Do You Want\nto See Patients?"
        case .redFlag: "Spot the\nRed Flag"
        case .name: "What Should\nWe Call You?"
        case .missCards: "Learn From\nEvery Miss"
        case .reminder: "When Should We\nRemind You?"
        case .promise: "Think Like\na Doctor"
        case .plan: "Your Rounds\nAre Ready"
        case .account: "Save Your\nProgress"
        case .focus, .pledge: nil
        }
    }
}
