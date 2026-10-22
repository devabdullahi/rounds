import Foundation

/// Every onboarding step, in order. Ordered for attention: one promise page, a scripted interview to
/// try (show, don't tell), then quick questions
/// early (fast progress), a value page between groups of answers, the heavier focus picker mid-flow,
/// the answers read back as a plan, the AI consent (before anything is sent to an AI provider),
/// then the account (only when onboarding began signed out) and the promise. They're pages of one carousel (`OnboardingView`), so every step slides the same way.
enum OnboardingPage: Int, CaseIterable {
    case patients, tryInterview, schoolYear, studyGoal, examReady, graded, focus, careSetting, struggles, redFlag, talkStyle,
         caseMode, caseTimer, name, promise, missCards, progress, dailyGoal, reminder, plan, aiConsent, account, pledge

    /// Question pages share one layout (question on top, answers as a list); the rest show art.
    var isQuestion: Bool {
        switch self {
        case .tryInterview, .schoolYear, .studyGoal, .careSetting, .struggles, .redFlag, .talkStyle, .caseMode, .caseTimer,
             .name, .dailyGoal, .reminder: true
        default: false
        }
    }

    /// Questions with no sensible default that the student may still pass over: nothing is saved
    /// and the flow goes on. The rest either need an answer (year, goal, name) or start answered.
    var isSkippable: Bool { self == .struggles || self == .redFlag }

    /// The big headline under the hero art, said with the student's answers so far where a page
    /// has a personal version. Question pages and the focus picker set their own title.
    func headline(_ personal: OnboardingHeadlines) -> String? {
        switch self {
        case .patients: "Interview Patients,\nFind the Diagnosis"
        case .examReady: personal.examReady
        case .graded: "Graded On\nEvery Move"
        case .promise: personal.promise
        case .missCards: personal.missCards
        case .progress: personal.progress
        case .plan: "Your Rounds\nAre Ready"
        case .account: "Create Your\nAccount"
        default: nil
        }
    }
}
