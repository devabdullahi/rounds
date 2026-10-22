import Foundation

/// Every onboarding step, in order (the design canvas's flow). The two quick questions first, then
/// the student's answers read back (what grading means for their exam, when it is, their plan),
/// a patient to try, voice, the account (only when onboarding began signed out), where they heard
/// about Rounds, and the promise. Reminders are asked after it, on their own screen (ReminderView). They're pages of one carousel (`OnboardingView`), so
/// every step slides the same way. The welcome screen before it and the paywall after it are
/// their own screens.
enum OnboardingPage: Int, CaseIterable {
    case schoolYear, studyGoal, gradedForYou, examDate, plan, tryInterview, voiceIntro, voiceTour,
         account, heardFrom, pledge

    /// Question pages share one layout (question on top, answers below) and a Continue button.
    var isQuestion: Bool {
        switch self {
        case .schoolYear, .studyGoal, .examDate, .tryInterview, .heardFrom: true
        default: false
        }
    }

    /// Questions the student may pass over: nothing is saved and the flow goes on.
    var isSkippable: Bool { self == .examDate || self == .heardFrom }

    /// What Skip says on a skippable page.
    var skipTitle: String { self == .examDate ? "Not sure yet" : "Skip" }
}
