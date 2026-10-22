import Foundation

/// What the student picked in onboarding, saved once to their account for product research (which
/// years, exams and struggles students arrive with). The app never reads it back. The name is left
/// out: only the picks, as their stored raw values.
struct OnboardingAnswers: Equatable, Sendable {
    var schoolYear: String?
    var studyGoal: String?
    var studyFocus: String?
    var careSetting: String?
    var struggles: [String] = []
    /// The mini-quiz option picked (0-3), and whether it was the red flag.
    var redFlagPick: Int?
    var redFlagCorrect: Bool?
    var voiceMode: Bool
    var examByDefault: Bool
    var timeLimitMinutes: Int
    var dailyGoal: Int
    var reminder: String?

    /// The picks as onboarding stored them on this phone. `redFlagPick` is the quiz option's id,
    /// which onboarding holds in memory only.
    static func stored(in defaults: UserDefaults = .standard, redFlagPick: String?) -> OnboardingAnswers {
        let text = { (key: String) in defaults.string(forKey: key).flatMap { $0.isEmpty ? nil : $0 } }
        let quiz = RedFlagQuiz.chestPain
        let pick = redFlagPick.flatMap { id in quiz.options.firstIndex { $0.id == id } }
        return OnboardingAnswers(
            schoolYear: text(SchoolYear.storageKey),
            studyGoal: text(StudyGoal.storageKey),
            studyFocus: text(StudyFocus.storageKey),
            careSetting: text(CareSetting.storageKey),
            struggles: StudyStruggle.allCases.filter(StudyStruggle.decode(text(StudyStruggle.storageKey) ?? "").contains).map(\.rawValue),
            redFlagPick: pick,
            redFlagCorrect: pick.map { quiz.options[$0].isRedFlag },
            voiceMode: defaults.object(forKey: Preferences.voiceModeKey) as? Bool ?? Preferences.voiceModeDefault,
            examByDefault: defaults.object(forKey: Preferences.examByDefaultKey) as? Bool ?? Preferences.examByDefaultDefault,
            timeLimitMinutes: defaults.object(forKey: TimeLimit.storageKey) as? Int ?? TimeLimit.defaultMinutes,
            dailyGoal: DailyGoal(stored: defaults.object(forKey: DailyGoal.storageKey) as? Int ?? DailyGoal.default.rawValue).rawValue,
            reminder: text(PracticeReminder.storageKey))
    }
}
