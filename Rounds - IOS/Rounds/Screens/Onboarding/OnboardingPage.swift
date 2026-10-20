import Foundation

/// Every onboarding step, in order. Ordered for attention: one promise page, then quick questions
/// early (fast progress), a value page between groups of answers, the heavier focus picker mid-flow,
/// the answers read back as a plan, then the account (only when onboarding began signed out) and
/// the promise. They're pages of one carousel (`OnboardingView`), so every step slides the same way.
enum OnboardingPage: Int, CaseIterable {
    case patients, schoolYear, studyGoal, examReady, graded, focus, careSetting, struggles, redFlag, talkStyle,
         caseMode, caseTimer, name, promise, missCards, progress, dailyGoal, reminder, plan, account, pledge

    /// Question pages share one layout (question on top, answers as a list); the rest show art.
    var isQuestion: Bool {
        switch self {
        case .schoolYear, .studyGoal, .careSetting, .struggles, .redFlag, .talkStyle, .caseMode, .caseTimer,
             .name, .dailyGoal, .reminder: true
        default: false
        }
    }

    /// The big headline under the hero art. Question pages and the focus picker set their own title.
    var headline: String? {
        switch self {
        case .patients: "Patients Who\nTalk Back"
        case .examReady: "Walk Into Your\nExam Ready"
        case .graded: "Graded On\nEvery Move"
        case .promise: "Think Like\na Doctor"
        case .missCards: "Learn From\nEvery Miss"
        case .progress: "See Where You're\nGetting Better"
        case .plan: "Your Rounds\nAre Ready"
        case .account: "Save Your\nProgress"
        default: nil
        }
    }
}
