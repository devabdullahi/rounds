import Foundation

/// Every onboarding step, in order (the design canvas's flow, shaped like Ahead's: questions about
/// the student, then a plan built from them, then the paywall). The quick questions (year, goal,
/// what to practice, whether they blank, and a line back for that answer), when the exam is and
/// how many weeks that leaves, how sure they feel and a reality check built from those answers,
/// their pace and study time, a short "setting up" beat, their plan,
/// the account (only when onboarding began signed out), where they heard about Rounds, and the
/// promise. Students meet their first real patient after onboarding; reminders are asked after
/// it, on their own screen (ReminderView). They're pages of one carousel (`OnboardingView`), so
/// every step slides the same way. The welcome screen before it and the paywall after it are
/// their own screens.
enum OnboardingPage: Int, CaseIterable {
    case schoolYear, studyGoal, practice, blanked, blankedReply, examDate, countdown, confidence,
         pace, realityCheck, studyTime, settingUp, plan, account, heardFrom, pledge

    /// Question pages share one layout (question on top, answers below) and a Continue button.
    var isQuestion: Bool {
        switch self {
        case .schoolYear, .studyGoal, .practice, .blanked, .examDate, .confidence, .studyTime, .heardFrom: true
        default: false
        }
    }
}
