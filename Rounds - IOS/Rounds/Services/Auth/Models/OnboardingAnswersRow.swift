import Foundation

/// `public.onboarding_answers` as the app writes it (insert only; the app can't read it back).
struct OnboardingAnswersRow: Encodable {
    let user_id: UUID
    let school_year: String?
    let study_goal: String?
    let study_focus: String?
    let care_setting: String?
    let struggles: [String]
    let voice_mode: Bool
    let exam_by_default: Bool
    let time_limit_minutes: Int
    let daily_goal: Int
    let reminder: String?
    let app_version: String

    init(userID: UUID, answers: OnboardingAnswers, appVersion: String) {
        user_id = userID
        school_year = answers.schoolYear
        study_goal = answers.studyGoal
        study_focus = answers.studyFocus
        care_setting = answers.careSetting
        struggles = answers.struggles
        voice_mode = answers.voiceMode
        exam_by_default = answers.examByDefault
        time_limit_minutes = answers.timeLimitMinutes
        daily_goal = answers.dailyGoal
        reminder = answers.reminder
        app_version = String(appVersion.prefix(40))
    }
}
