import Foundation

/// Every onboarding step, in order (the design canvas's flow, shaped like Ahead's: questions about
/// the student, then a plan built from them, then the paywall). The quick questions (year, goal,
/// what to practice), the answers read back (exam tips, when the exam is), how sure they feel and
/// a reality check built from those answers, their pace, a short "setting up" beat, their plan,
/// the account (only when onboarding began signed out), where they heard about Rounds, and the
/// promise. Students meet their first real patient after onboarding; reminders are asked after
/// it, on their own screen (ReminderView). They're pages of one carousel (`OnboardingView`), so
/// every step slides the same way. The welcome screen before it and the paywall after it are
/// their own screens.
enum OnboardingPage: Int, CaseIterable {
    case schoolYear, studyGoal, practice, gradedForYou, examDate, confidence, realityCheck, pace,
         settingUp, plan, account, heardFrom, pledge

    /// Question pages share one layout (question on top, answers below) and a Continue button.
    var isQuestion: Bool {
        switch self {
        case .schoolYear, .studyGoal, .practice, .examDate, .confidence, .heardFrom: true
        default: false
        }
    }

    /// Questions the student may pass over: nothing is saved and the flow goes on.
    var isSkippable: Bool { self == .examDate || self == .heardFrom }

    /// What Skip says on a skippable page.
    var skipTitle: String { self == .examDate ? "Not sure yet" : "Skip" }
}
